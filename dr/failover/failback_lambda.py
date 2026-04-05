"""
DR Failback Orchestration Lambda
Step Functions에서 각 Step별로 호출됨

장애 해소 후 도쿄(DR) → 서울(Primary) 자동 복구 수행

action:
  - check_primary_health   : 서울 ALB 헬스체크 통과 여부 확인
  - aurora_failback        : Aurora Global DB 도쿄 → 서울 재승격
  - restore_ssm_endpoints  : 서울 원본 SSM 파라미터 복구
  - activate_primary_ecs   : 서울 ECS desired_count 복구 (0 → 2)
  - deactivate_dr_ecs      : 도쿄 ECS desired_count 0으로
  - cleanup_dr_agentcore   : 도쿄 AgentCore Runtime 삭제
  - notify                 : SNS 완료 알림
"""
import boto3
import os
import json
import logging
import time
import urllib.request

logger = logging.getLogger()
logger.setLevel(logging.INFO)

PRIMARY_REGION = os.environ["PRIMARY_REGION"]
DR_REGION      = os.environ["DR_REGION"]
PROJECT_NAME   = os.environ["PROJECT_NAME"]
ENVIRONMENT    = os.environ["ENVIRONMENT"]
SNS_TOPIC_ARN  = os.environ["SNS_TOPIC_ARN"]
PRIMARY_ALB_DNS = os.environ.get("PRIMARY_ALB_DNS", "")

# Aurora Global Cluster 식별자 (failover_lambda.py와 동일)
AURORA_GLOBAL_CLUSTERS = {
    "cluster1": f"{PROJECT_NAME}-{ENVIRONMENT}-users-cluster-global",
    "cluster2": f"{PROJECT_NAME}-{ENVIRONMENT}-history-cluster-global",
    "cluster3": f"{PROJECT_NAME}-{ENVIRONMENT}-analysis-cluster-global",
    "cluster4": f"{PROJECT_NAME}-{ENVIRONMENT}-chatbot-cluster-global",
}

# 서울 Primary 클러스터 ARN을 SSM에서 조회하기 위한 키
PRIMARY_CLUSTER_ARNS_SSM_KEY = f"/{PROJECT_NAME}/{ENVIRONMENT}/aurora-cluster-arns"

# ECS 서비스 목록
ECS_SERVICES = ["users", "history", "chatbot", "analysis", "frontend"]

# AgentCore 에이전트 정보 (DR SSM에 저장된 Runtime ARN 키)
AGENTCORE_AGENTS = {
    "analysis": f"/{PROJECT_NAME}/{ENVIRONMENT}/dr/agentcore/analysis-agent/runtime-arn",
    "chatbot":  f"/{PROJECT_NAME}/{ENVIRONMENT}/dr/agentcore/chatbot-agent/runtime-arn",
    "summary":  f"/{PROJECT_NAME}/{ENVIRONMENT}/dr/agentcore/summary-agent/runtime-arn",
}


# ── Action 핸들러 ─────────────────────────────────────────────────

def check_primary_health(event):
    """
    서울 ALB 헬스체크 통과 여부 확인
    - /health 엔드포인트 HTTP 200 응답 확인
    - 실패 시 Step Functions에서 Wait 후 재시도
    """
    # Failback 시작 시 Failover EventBridge 규칙 비활성화 (루프 방지)
    events = boto3.client("events", region_name=PRIMARY_REGION)
    failover_rule = f"{PROJECT_NAME}-{ENVIRONMENT}-dr-trigger"
    try:
        events.disable_rule(Name=failover_rule)
        logger.info(f"Failover EventBridge 규칙 비활성화: {failover_rule}")
    except Exception as e:
        logger.warning(f"Failover 규칙 비활성화 실패 (무시): {e}")
    alb_dns = PRIMARY_ALB_DNS
    if not alb_dns:
        raise ValueError("PRIMARY_ALB_DNS 환경변수가 설정되지 않았습니다")

    health_url = f"https://{alb_dns}/health"
    logger.info(f"서울 ALB 헬스체크 시작: {health_url}")

    try:
        req = urllib.request.Request(health_url, method="GET")
        req.add_header("User-Agent", "DR-Failback-HealthCheck/1.0")
        import ssl
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        with urllib.request.urlopen(req, timeout=10, context=ctx) as resp:
            status_code = resp.status
            logger.info(f"헬스체크 응답: HTTP {status_code}")
            if status_code == 200:
                return {"action": "check_primary_health", "status": "healthy", "http_status": status_code}
            raise RuntimeError(f"헬스체크 실패: HTTP {status_code}")
    except Exception as e:
        logger.warning(f"서울 ALB 헬스체크 실패: {e}")
        raise RuntimeError(f"서울 ALB 헬스체크 실패 - 재시도 필요: {e}")


def aurora_failback(event):
    """
    Aurora Global DB Failback: 도쿄 Primary → 서울 Secondary 재승격
    - 서울 클러스터가 available 상태인지 먼저 확인
    - 데이터 손실 방지를 위해 서울 클러스터 완전 복구 후 수행
    """
    rds_primary = boto3.client("rds", region_name=PRIMARY_REGION)
    ssm_primary = boto3.client("ssm", region_name=PRIMARY_REGION)

    # 서울 Primary 클러스터 ARN 조회 (SSM에 미리 저장된 원본 값)
    try:
        primary_cluster_arns = json.loads(
            ssm_primary.get_parameter(Name=PRIMARY_CLUSTER_ARNS_SSM_KEY)["Parameter"]["Value"]
        )
    except Exception as e:
        raise RuntimeError(f"서울 클러스터 ARN 조회 실패 ({PRIMARY_CLUSTER_ARNS_SSM_KEY}): {e}")

    results = {}
    for key, global_id in AURORA_GLOBAL_CLUSTERS.items():
        primary_cluster_arn = primary_cluster_arns.get(key)
        if not primary_cluster_arn:
            logger.warning(f"서울 클러스터 ARN 없음: {key}, 건너뜀")
            results[key] = "skipped: no primary cluster ARN"
            continue

        # 서울 클러스터 available 상태 확인 (최대 10분 대기)
        cluster_id = primary_cluster_arn.split(":")[-1]
        logger.info(f"서울 클러스터 상태 확인: {cluster_id}")
        available = False
        for attempt in range(60):
            try:
                resp = rds_primary.describe_db_clusters(DBClusterIdentifier=cluster_id)
                status = resp["DBClusters"][0]["Status"]
                logger.info(f"{cluster_id} 상태: {status} ({attempt + 1}/60)")
                if status == "available":
                    available = True
                    break
            except Exception as e:
                logger.warning(f"클러스터 상태 조회 실패: {e}")
            time.sleep(10)

        if not available:
            raise RuntimeError(f"서울 클러스터 복구 대기 시간 초과: {cluster_id}")

        # Aurora Global DB Failback 실행 (서울 클러스터로 재승격)
        try:
            rds_primary.failover_global_cluster(
                GlobalClusterIdentifier=global_id,
                TargetDbClusterIdentifier=primary_cluster_arn,
            )
            logger.info(f"Aurora Failback 시작: {global_id} → {primary_cluster_arn}")
            results[key] = "initiated"
        except Exception as e:
            logger.error(f"Aurora Failback 실패 ({global_id}): {e}")
            results[key] = f"error: {e}"

    return {"action": "aurora_failback", "results": results}


def restore_ssm_endpoints(event):
    """
    서울 원본 Aurora endpoint → SSM 파라미터 복구
    - 서울 클러스터 Failback 완료(available) 대기 후 endpoint 갱신
    """
    rds = boto3.client("rds", region_name=PRIMARY_REGION)
    ssm = boto3.client("ssm", region_name=PRIMARY_REGION)

    # 서울 Primary 클러스터 식별자 맵
    cluster_map = {
        "users":    f"{PROJECT_NAME}-{ENVIRONMENT}-users-cluster",
        "history":  f"{PROJECT_NAME}-{ENVIRONMENT}-history-cluster",
        "analysis": f"{PROJECT_NAME}-{ENVIRONMENT}-analysis-cluster",
        "chatbot":  f"{PROJECT_NAME}-{ENVIRONMENT}-chatbot-cluster",
    }

    results = {}
    for service, cluster_id in cluster_map.items():
        try:
            # Failback 완료 대기 (최대 10분)
            for attempt in range(60):
                resp = rds.describe_db_clusters(DBClusterIdentifier=cluster_id)
                cluster = resp["DBClusters"][0]
                status = cluster["Status"]
                logger.info(f"{cluster_id} 상태: {status} ({attempt + 1}/60)")
                if status == "available":
                    break
                time.sleep(10)
            else:
                raise RuntimeError(f"클러스터 복구 대기 시간 초과: {cluster_id}")

            endpoint = cluster["Endpoint"]
            port     = str(cluster["Port"])
            db_name  = cluster["DatabaseName"]

            # 서울 원본 SSM 파라미터 복구
            base_key = f"/{PROJECT_NAME}/{ENVIRONMENT}/rds/{service}-cluster"
            ssm.put_parameter(Name=f"{base_key}/endpoint", Value=endpoint, Type="String", Overwrite=True)
            ssm.put_parameter(Name=f"{base_key}/port",     Value=port,     Type="String", Overwrite=True)
            ssm.put_parameter(Name=f"{base_key}/dbname",   Value=db_name,  Type="String", Overwrite=True)

            logger.info(f"SSM 복구 완료 ({service}): {endpoint}")
            results[service] = endpoint
        except Exception as e:
            logger.error(f"SSM 복구 실패 ({service}): {e}")
            results[service] = f"error: {e}"

    return {"action": "restore_ssm_endpoints", "results": results}


def activate_primary_ecs(event):
    """
    서울 ECS 서비스 desired_count 복구 (0 → 2)
    - Aurora 재연결 확인 후 서비스 활성화
    """
    ecs = boto3.client("ecs", region_name=PRIMARY_REGION)
    cluster = f"{PROJECT_NAME}-{ENVIRONMENT}-cluster"

    results = {}
    for service in ECS_SERVICES:
        service_name = f"{PROJECT_NAME}-{ENVIRONMENT}-{service}-service"
        try:
            ecs.update_service(
                cluster=cluster,
                service=service_name,
                desiredCount=2,
            )
            logger.info(f"서울 ECS 서비스 활성화: {service_name}")
            results[service] = "activated"
        except Exception as e:
            logger.error(f"서울 ECS 활성화 실패 ({service_name}): {e}")
            results[service] = f"error: {e}"

    return {"action": "activate_primary_ecs", "results": results}


def deactivate_dr_ecs(event):
    """
    도쿄 DR ECS 서비스 비활성화 (desired_count 2 → 0)
    - 서울 완전 복구 확인 후 수행 (동시 비활성화 금지)
    """
    ecs = boto3.client("ecs", region_name=DR_REGION)
    cluster = f"{PROJECT_NAME}-{ENVIRONMENT}-dr-cluster"

    # 서울 ECS 서비스가 정상 running 상태인지 먼저 확인
    ecs_primary = boto3.client("ecs", region_name=PRIMARY_REGION)
    primary_cluster = f"{PROJECT_NAME}-{ENVIRONMENT}-cluster"

    logger.info("서울 ECS 서비스 running 상태 확인 중...")
    for attempt in range(30):  # 최대 5분 대기
        all_running = True
        for service in ECS_SERVICES:
            service_name = f"{PROJECT_NAME}-{ENVIRONMENT}-{service}-service"
            try:
                resp = ecs_primary.describe_services(cluster=primary_cluster, services=[service_name])
                svc = resp["services"][0]
                running = svc.get("runningCount", 0)
                desired = svc.get("desiredCount", 2)
                if running < desired:
                    logger.info(f"{service_name}: running={running}/{desired} ({attempt + 1}/30)")
                    all_running = False
                    break
            except Exception as e:
                logger.warning(f"서울 ECS 상태 조회 실패 ({service_name}): {e}")
                all_running = False
                break

        if all_running:
            logger.info("서울 ECS 서비스 모두 정상 running 확인")
            break
        time.sleep(10)
    else:
        raise RuntimeError("서울 ECS 서비스 복구 대기 시간 초과 - 도쿄 비활성화 중단")

    # 도쿄 DR ECS 비활성화
    results = {}
    for service in ECS_SERVICES:
        service_name = f"{PROJECT_NAME}-{ENVIRONMENT}-dr-{service}-service"
        try:
            ecs.update_service(
                cluster=cluster,
                service=service_name,
                desiredCount=0,
            )
            logger.info(f"도쿄 DR ECS 비활성화: {service_name}")
            results[service] = "deactivated"
        except Exception as e:
            logger.error(f"도쿄 DR ECS 비활성화 실패 ({service_name}): {e}")
            results[service] = f"error: {e}"

    return {"action": "deactivate_dr_ecs", "results": results}


def cleanup_dr_agentcore(event):
    """
    도쿄 AgentCore Runtime 삭제
    - SSM에 저장된 Runtime ARN 조회 후 삭제
    - 삭제 후 SSM 파라미터 초기화
    """
    agentcore = boto3.client("bedrock-agentcore-control", region_name=DR_REGION)
    ssm_dr    = boto3.client("ssm", region_name=DR_REGION)

    results = {}
    for agent_key, ssm_key in AGENTCORE_AGENTS.items():
        try:
            # SSM에서 Runtime ARN 조회
            runtime_arn = ssm_dr.get_parameter(Name=ssm_key)["Parameter"]["Value"]
            if not runtime_arn or runtime_arn == "none":
                logger.info(f"DR AgentCore Runtime 없음 ({agent_key}), 건너뜀")
                results[agent_key] = "skipped: no runtime"
                continue

            # Runtime ID 추출 (ARN 마지막 세그먼트)
            runtime_id = runtime_arn.split("/")[-1]

            # AgentCore Runtime 삭제
            agentcore.delete_agent_runtime(agentRuntimeId=runtime_id)
            logger.info(f"DR AgentCore Runtime 삭제: {agent_key} ({runtime_id})")

            # SSM 파라미터 초기화
            ssm_dr.put_parameter(Name=ssm_key, Value="none", Type="String", Overwrite=True)
            results[agent_key] = "deleted"
        except ssm_dr.exceptions.ParameterNotFound:
            logger.info(f"SSM 파라미터 없음 ({ssm_key}), 건너뜀")
            results[agent_key] = "skipped: ssm not found"
        except Exception as e:
            logger.error(f"DR AgentCore 삭제 실패 ({agent_key}): {e}")
            results[agent_key] = f"error: {e}"

    return {"action": "cleanup_dr_agentcore", "results": results}


def notify(event):
    """Failback 완료/실패 SNS 알림"""
    # Failback 완료 시 Failover EventBridge 규칙 재활성화
    events_client = boto3.client("events", region_name=PRIMARY_REGION)
    failover_rule = f"{PROJECT_NAME}-{ENVIRONMENT}-dr-trigger"
    try:
        events_client.enable_rule(Name=failover_rule)
        logger.info(f"Failover EventBridge 규칙 재활성화: {failover_rule}")
    except Exception as e:
        logger.warning(f"Failover 규칙 재활성화 실패 (무시): {e}")

    sns = boto3.client("sns", region_name=PRIMARY_REGION)
    status  = event.get("status", "UNKNOWN")
    message = event.get("message", "")

    subject = f"[DR Failback] {PROJECT_NAME} {status}: 도쿄 → 서울 복구"
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message=json.dumps(event, indent=2, ensure_ascii=False),
    )
    logger.info(f"SNS 알림 전송: {subject}")
    return {"action": "notify", "status": "sent", "message": message}


# ── Lambda 핸들러 ─────────────────────────────────────────────────

def lambda_handler(event, context):
    action = event.get("action")
    logger.info(f"DR Failback action: {action}, event: {json.dumps(event, ensure_ascii=False)}")

    dispatch = {
        "check_primary_health":  check_primary_health,
        "aurora_failback":       aurora_failback,
        "restore_ssm_endpoints": restore_ssm_endpoints,
        "activate_primary_ecs":  activate_primary_ecs,
        "deactivate_dr_ecs":     deactivate_dr_ecs,
        "cleanup_dr_agentcore":  cleanup_dr_agentcore,
        "notify":                notify,
    }

    handler = dispatch.get(action)
    if not handler:
        raise ValueError(f"알 수 없는 action: {action}")

    return handler(event)

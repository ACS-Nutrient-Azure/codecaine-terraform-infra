"""
DR Failover Orchestration Lambda
Step Functions에서 각 Step별로 호출됨

action:
  - aurora_failover      : Aurora Global DB Failover (4개 클러스터)
  - activate_ecs         : DR ECS desired_count 0 → 2
  - provision_agentcore  : DR AgentCore Runtime 생성 (provisioner Lambda 호출)
  - update_ssm_endpoints : DR DB endpoint → SSM 파라미터 업데이트
  - notify               : SNS 완료 알림
"""
import boto3
import os
import json
import logging
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

PRIMARY_REGION = os.environ["PRIMARY_REGION"]
DR_REGION      = os.environ["DR_REGION"]
PROJECT_NAME   = os.environ["PROJECT_NAME"]
ENVIRONMENT    = os.environ["ENVIRONMENT"]
SNS_TOPIC_ARN  = os.environ["SNS_TOPIC_ARN"]

AURORA_GLOBAL_CLUSTERS = {
    "cluster1": f"{PROJECT_NAME}-{ENVIRONMENT}-users-cluster-global",
    "cluster2": f"{PROJECT_NAME}-{ENVIRONMENT}-history-cluster-global",
    "cluster3": f"{PROJECT_NAME}-{ENVIRONMENT}-analysis-cluster-global",
    "cluster4": f"{PROJECT_NAME}-{ENVIRONMENT}-chatbot-cluster-global",
}

DR_CLUSTER_ARNS_SSM_KEY = f"/{PROJECT_NAME}/{ENVIRONMENT}/dr/aurora-cluster-arns"

ECS_SERVICES = ["users", "history", "chatbot", "analysis", "frontend"]
ECS_CLUSTER  = f"{PROJECT_NAME}-{PROJECT_NAME}-dr-cluster"  # dr/compute에서 생성

AGENTCORE_AGENTS = {
    "analysis": {
        "name":    f"{PROJECT_NAME}_{ENVIRONMENT}_analysis_agent".replace("-", "_"),
        "ssm_key": f"/{PROJECT_NAME}/{ENVIRONMENT}/dr/agentcore/analysis-agent/runtime-arn",
        "env":     {"LAMBDA_FUNCTION_NAME": f"{PROJECT_NAME}-{ENVIRONMENT}-dr-nutrient-calc"},
    },
    "chatbot": {
        "name":    f"{PROJECT_NAME}_{ENVIRONMENT}_chatbot_agent".replace("-", "_"),
        "ssm_key": f"/{PROJECT_NAME}/{ENVIRONMENT}/dr/agentcore/chatbot-agent/runtime-arn",
        "env":     {},
    },
    "summary": {
        "name":    f"{PROJECT_NAME}_{ENVIRONMENT}_summary_agent".replace("-", "_"),
        "ssm_key": f"/{PROJECT_NAME}/{ENVIRONMENT}/dr/agentcore/summary-agent/runtime-arn",
        "env":     {},
    },
}


def aurora_failover(event):
    """Aurora Global DB Failover → 도쿄 Secondary를 Primary로 승격"""
    rds = boto3.client("rds", region_name=PRIMARY_REGION)
    ssm = boto3.client("ssm", region_name=PRIMARY_REGION)

    # DR 클러스터 ARN은 SSM에 저장 (dr/database 모듈 outputs에서 미리 저장)
    dr_cluster_arns = json.loads(
        ssm.get_parameter(Name=DR_CLUSTER_ARNS_SSM_KEY)["Parameter"]["Value"]
    )

    # 모든 클러스터 Failover 동시 시작
    for key, global_id in AURORA_GLOBAL_CLUSTERS.items():
        try:
            rds.failover_global_cluster(
                GlobalClusterIdentifier=global_id,
                TargetDbClusterIdentifier=dr_cluster_arns[key],
            )
            logger.info(f"Aurora failover initiated: {global_id} → {dr_cluster_arns[key]}")
        except Exception as e:
            logger.error(f"Aurora failover failed for {global_id}: {e}")

    # 모든 클러스터 Failover 완료 대기 (도쿄가 IsWriter=true 될 때까지, 최대 5분)
    results = {}
    for key, global_id in AURORA_GLOBAL_CLUSTERS.items():
        dr_arn = dr_cluster_arns[key]
        completed = False
        for attempt in range(30):
            try:
                resp = rds.describe_global_clusters(GlobalClusterIdentifier=global_id)
                members = resp["GlobalClusters"][0]["GlobalClusterMembers"]
                dr_writer = next((m for m in members if m["DBClusterArn"] == dr_arn and m["IsWriter"]), None)
                if dr_writer:
                    logger.info(f"Aurora failover completed: {global_id} → {dr_arn} is now Primary")
                    results[key] = "completed"
                    completed = True
                    break
                logger.info(f"Waiting for {global_id} failover... attempt {attempt + 1}/30")
            except Exception as e:
                logger.warning(f"describe_global_clusters error for {global_id}: {e}")
            time.sleep(10)

        if not completed:
            logger.error(f"Aurora failover timed out for {global_id}")
            results[key] = "timeout"

    return {"action": "aurora_failover", "results": results}


def activate_ecs(event):
    """DR ECS 서비스 desired_count 0 → 2"""
    ecs = boto3.client("ecs", region_name=DR_REGION)
    cluster = f"{PROJECT_NAME}-{ENVIRONMENT}-dr-cluster"

    results = {}
    for service in ECS_SERVICES:
        service_name = f"{PROJECT_NAME}-{ENVIRONMENT}-dr-{service}-service"
        try:
            ecs.update_service(
                cluster=cluster,
                service=service_name,
                desiredCount=2,
            )
            logger.info(f"ECS service activated: {service_name}")
            results[service] = "activated"
        except Exception as e:
            logger.error(f"ECS activate failed for {service_name}: {e}")
            results[service] = f"error: {e}"

    return {"action": "activate_ecs", "results": results}


def provision_agentcore(event):
    """DR AgentCore Runtime 생성 (DR provisioner Lambda 호출)"""
    lambda_client = boto3.client("lambda", region_name=DR_REGION)
    ssm           = boto3.client("ssm", region_name=DR_REGION)

    provisioner_name = f"{PROJECT_NAME}-{ENVIRONMENT}-dr-agentcore-provisioner"
    ecr_base = f"{boto3.client('sts').get_caller_identity()['Account']}.dkr.ecr.{DR_REGION}.amazonaws.com"

    results = {}
    for agent_key, agent in AGENTCORE_AGENTS.items():
        role_ssm_key = f"/{PROJECT_NAME}/{ENVIRONMENT}/dr/agentcore/{agent_key}-role-arn"
        try:
            role_arn = ssm.get_parameter(Name=role_ssm_key)["Parameter"]["Value"]
        except Exception:
            logger.warning(f"Role ARN not found in SSM: {role_ssm_key}, skipping")
            continue

        payload = {
            "region":     DR_REGION,
            "agent_name": agent["name"],
            "image_uri":  f"{ecr_base}/{PROJECT_NAME}-{ENVIRONMENT}-{agent_key}-agent:latest",
            "role_arn":   role_arn,
            "ssm_key":    agent["ssm_key"],
            "network_mode": "PUBLIC",
        }
        if agent["env"]:
            payload["environment_variables"] = agent["env"]

        try:
            resp = lambda_client.invoke(
                FunctionName=provisioner_name,
                InvocationType="RequestResponse",
                Payload=json.dumps(payload),
            )
            result = json.loads(resp["Payload"].read())
            logger.info(f"AgentCore provisioned: {agent_key} → {result.get('runtime_arn')}")
            results[agent_key] = result.get("runtime_arn", "skipped")
        except Exception as e:
            logger.error(f"AgentCore provision failed for {agent_key}: {e}")
            results[agent_key] = f"error: {e}"

    return {"action": "provision_agentcore", "results": results}


def update_ssm_endpoints(event):
    """DR Aurora endpoint → SSM 파라미터 업데이트 (ECS Task가 참조)"""
    rds = boto3.client("rds", region_name=DR_REGION)
    ssm = boto3.client("ssm", region_name=DR_REGION)

    cluster_map = {
        "users":    f"{PROJECT_NAME}-{ENVIRONMENT}-dr-users-cluster",
        "history":  f"{PROJECT_NAME}-{ENVIRONMENT}-dr-history-cluster",
        "analysis": f"{PROJECT_NAME}-{ENVIRONMENT}-dr-analysis-cluster",
        "chatbot":  f"{PROJECT_NAME}-{ENVIRONMENT}-dr-chatbot-cluster",
    }

    results = {}
    for service, cluster_id in cluster_map.items():
        try:
            # Aurora Failover 완료 대기 (최대 5분)
            for _ in range(30):
                resp = rds.describe_db_clusters(DBClusterIdentifier=cluster_id)
                cluster = resp["DBClusters"][0]
                if cluster["Status"] == "available":
                    break
                logger.info(f"Waiting for {cluster_id} to be available...")
                time.sleep(10)

            endpoint = cluster["Endpoint"]
            port     = str(cluster["Port"])
            db_name  = cluster["DatabaseName"]

            base_key = f"/{PROJECT_NAME}/{ENVIRONMENT}/rds/{service}-cluster"
            ssm.put_parameter(Name=f"{base_key}/endpoint",  Value=endpoint,                    Type="String", Overwrite=True)
            ssm.put_parameter(Name=f"{base_key}/port",      Value=port,                        Type="String", Overwrite=True)
            ssm.put_parameter(Name=f"{base_key}/dbname",    Value=db_name,                     Type="String", Overwrite=True)
            ssm.put_parameter(Name=f"{base_key}/username",  Value=cluster["MasterUsername"],   Type="String", Overwrite=True)

            # Secrets Manager: 서울 secret을 도쿄에 복제 (없는 경우)
            secret_name = f"{PROJECT_NAME}-{ENVIRONMENT}-{service}-cluster-secret"
            sm_primary = boto3.client("secretsmanager", region_name=PRIMARY_REGION)
            sm_dr      = boto3.client("secretsmanager", region_name=DR_REGION)
            try:
                secret_value = sm_primary.get_secret_value(SecretId=secret_name)["SecretString"]
                try:
                    sm_dr.put_secret_value(SecretId=secret_name, SecretString=secret_value)
                except sm_dr.exceptions.ResourceNotFoundException:
                    sm_dr.create_secret(Name=secret_name, SecretString=secret_value)
                logger.info(f"Secret synced for {service}")
            except Exception as e:
                logger.warning(f"Secret sync failed for {service}: {e}")

            logger.info(f"SSM updated for {service}: {endpoint}")
            results[service] = endpoint
        except Exception as e:
            logger.error(f"SSM update failed for {service}: {e}")
            results[service] = f"error: {e}"

    return {"action": "update_ssm_endpoints", "results": results}


def notify(event):
    """DR 완료 SNS 알림"""
    sns = boto3.client("sns", region_name=PRIMARY_REGION)
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"[DR] {PROJECT_NAME} Failover 완료 → {DR_REGION}",
        Message=json.dumps(event, indent=2, ensure_ascii=False),
    )
    return {"action": "notify", "status": "sent"}


def lambda_handler(event, context):
    action = event.get("action")
    logger.info(f"DR Failover action: {action}")

    dispatch = {
        "aurora_failover":     aurora_failover,
        "activate_ecs":        activate_ecs,
        "provision_agentcore": provision_agentcore,
        "update_ssm_endpoints": update_ssm_endpoints,
        "notify":              notify,
    }

    handler = dispatch.get(action)
    if not handler:
        raise ValueError(f"Unknown action: {action}")

    return handler(event)

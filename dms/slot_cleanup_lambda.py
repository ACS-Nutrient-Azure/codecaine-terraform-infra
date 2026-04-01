"""
DMS Replication Slot Cleanup Lambda

DMS task 중단/재생성 시 Aurora PostgreSQL에 남은 비활성 replication slot이
WAL 로그를 장기 누적시켜 디스크를 꽉 채우는 문제를 방지합니다.

삭제 조건 (모두 충족해야 삭제):
  1. slot_name이 DMS prefix (awsdms_, dms_) 로 시작
  2. active = false  (현재 연결된 consumer 없음)
  3. inactive_since 기준 WAL lag 누적 시간 > WAL_LAG_STALE_HOURS (기본 2시간)
     OR wal_lag_bytes > WAL_LAG_CLEANUP_THRESHOLD (기본 5GB)

action:
  - list_slots             : 전체 slot 상태 조회 (삭제 없음)
  - cleanup_stale_slots    : 장기 누적 + 연결 없는 DMS slot 삭제
  - notify                 : SNS 알림
"""
import boto3
import os
import json
import logging
import datetime
import pg8000.native

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REGION       = os.environ["REGION"]
PROJECT_NAME = os.environ["PROJECT_NAME"]
ENVIRONMENT  = os.environ["ENVIRONMENT"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

# DMS slot prefix (이 prefix를 가진 slot만 삭제 대상)
DMS_SLOT_PREFIXES = ("awsdms_", "dms_")

# 대상 Aurora 클러스터 서비스명
AURORA_SERVICES = ["users", "history", "analysis", "chatbot"]

# 삭제 임계값
WAL_LAG_CLEANUP_THRESHOLD = 5 * 1024 * 1024 * 1024  # 5GB
WAL_LAG_STALE_HOURS       = 2                         # 2시간 이상 비활성


def _get_secret(service: str) -> dict:
    """Secrets Manager에서 DB 자격증명 조회 (dms/main.tf와 동일한 secret 이름 패턴)"""
    client    = boto3.client("secretsmanager", region_name=REGION)
    secret_id = f"{PROJECT_NAME}-{ENVIRONMENT}-{service}-cluster-secret"
    return json.loads(client.get_secret_value(SecretId=secret_id)["SecretString"])


def _connect(service: str):
    """pg8000으로 Aurora PostgreSQL 연결"""
    s = _get_secret(service)
    return pg8000.native.Connection(
        host=s["host"],
        port=int(s.get("port", 5432)),
        user=s["username"],
        password=s["password"],
        database=s.get("dbname", "postgres"),
        ssl_context=True,
        timeout=10,
    )


def _is_dms_slot(slot_name: str) -> bool:
    return any(slot_name.startswith(p) for p in DMS_SLOT_PREFIXES)


def _query_slots(conn) -> list[dict]:
    """
    slot 상태 조회
    - active_pid: 현재 연결된 backend PID (NULL이면 연결 없음)
    - wal_lag_bytes: 미소비 WAL 크기
    - inactive_since: active=false가 된 시각 (PostgreSQL 14+)
    """
    # PostgreSQL 14+ 여부 확인 (inactive_since 컬럼 존재 여부)
    version_row = conn.run("SELECT current_setting('server_version_num')::int")
    pg_version = int(version_row[0][0])
    has_inactive_since = pg_version >= 140000

    if has_inactive_since:
        rows = conn.run("""
            SELECT
                slot_name,
                active,
                active_pid,
                pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)  AS wal_lag_bytes,
                inactive_since
            FROM pg_replication_slots
            ORDER BY wal_lag_bytes DESC NULLS LAST
        """)
    else:
        rows = conn.run("""
            SELECT
                slot_name,
                active,
                active_pid,
                pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)  AS wal_lag_bytes,
                NULL AS inactive_since
            FROM pg_replication_slots
            ORDER BY wal_lag_bytes DESC NULLS LAST
        """)

    now = datetime.datetime.now(datetime.timezone.utc)
    result = []
    for row in rows:
        slot_name, active, active_pid, wal_lag_bytes, inactive_since = row
        wal_lag_bytes = int(wal_lag_bytes) if wal_lag_bytes is not None else 0

        inactive_hours = None
        if inactive_since is not None:
            if inactive_since.tzinfo is None:
                inactive_since = inactive_since.replace(tzinfo=datetime.timezone.utc)
            inactive_hours = round((now - inactive_since).total_seconds() / 3600, 2)

        result.append({
            "slot_name":      slot_name,
            "active":         active,
            "active_pid":     active_pid,
            "wal_lag_bytes":  wal_lag_bytes,
            "wal_lag_gb":     round(wal_lag_bytes / (1024 ** 3), 2),
            "inactive_hours": inactive_hours,
        })
    return result


def _is_stale(slot: dict) -> bool:
    """
    삭제 대상 판단:
      - active=false (연결 없음, active_pid=None 이중 확인)
      - WAL lag > 5GB  OR  비활성 시간 > 2시간
    """
    if slot["active"] or slot["active_pid"] is not None:
        return False  # 현재 연결 중 → 절대 삭제 안 함

    wal_over  = slot["wal_lag_bytes"] >= WAL_LAG_CLEANUP_THRESHOLD
    time_over = (
        slot["inactive_hours"] is not None
        and slot["inactive_hours"] >= WAL_LAG_STALE_HOURS
    )
    # inactive_since 미지원 버전은 WAL lag만으로 판단
    if slot["inactive_hours"] is None:
        return wal_over

    return wal_over or time_over


# ── Action 핸들러 ─────────────────────────────────────────────────

def list_slots(event):
    """전체 slot 상태 조회 (삭제 없음) — EventBridge 30분 주기 모니터링용"""
    results            = {}
    total_stale_dms    = 0
    max_wal_lag_bytes  = 0

    for service in AURORA_SERVICES:
        conn = None
        try:
            conn  = _connect(service)
            slots = _query_slots(conn)

            stale_dms = [s for s in slots if _is_dms_slot(s["slot_name"]) and _is_stale(s)]
            total_stale_dms += len(stale_dms)

            if slots:
                max_wal_lag_bytes = max(max_wal_lag_bytes, max(s["wal_lag_bytes"] for s in slots))

            results[service] = {"slots": slots, "stale_dms_count": len(stale_dms)}
            logger.info(f"[{service}] 전체 {len(slots)}개, 정리 대상 DMS {len(stale_dms)}개")

        except Exception as e:
            logger.error(f"[{service}] 조회 실패: {e}")
            results[service] = {"error": str(e)}
        finally:
            if conn:
                try: conn.close()
                except Exception: pass

    # CloudWatch 커스텀 메트릭 발행
    try:
        cw = boto3.client("cloudwatch", region_name=REGION)
        cw.put_metric_data(
            Namespace=f"{PROJECT_NAME}/DMS",
            MetricData=[{
                "MetricName": "MaxWalLagBytes",
                "Value":      max_wal_lag_bytes,
                "Unit":       "Bytes",
                "Dimensions": [
                    {"Name": "Project",     "Value": PROJECT_NAME},
                    {"Name": "Environment", "Value": ENVIRONMENT},
                ],
            }],
        )
    except Exception as e:
        logger.warning(f"CloudWatch 메트릭 발행 실패: {e}")

    needs_cleanup = total_stale_dms > 0
    logger.info(f"list_slots 완료: 정리 대상 {total_stale_dms}개, cleanup 필요: {needs_cleanup}")

    # needs_cleanup=true이면 Lambda가 자기 자신을 호출해서 cleanup 실행
    if needs_cleanup:
        try:
            lambda_client = boto3.client("lambda", region_name=REGION)
            func_name     = f"{PROJECT_NAME}-{ENVIRONMENT}-dms-slot-cleanup"
            lambda_client.invoke(
                FunctionName   = func_name,
                InvocationType = "Event",  # 비동기
                Payload        = json.dumps({"action": "cleanup_stale_slots"}).encode(),
            )
            logger.info(f"cleanup_stale_slots 비동기 호출: {func_name}")
        except Exception as e:
            logger.error(f"cleanup 자동 호출 실패: {e}")

    return {
        "action":           "list_slots",
        "results":          results,
        "total_stale_dms":  total_stale_dms,
        "max_wal_lag_bytes": max_wal_lag_bytes,
        "needs_cleanup":    needs_cleanup,
    }


def cleanup_stale_slots(event):
    """
    장기 누적 + 연결 없는 DMS slot 삭제
    삭제 조건: DMS prefix + active=false + active_pid=None + (WAL>5GB OR 비활성>2h)
    """
    results       = {}
    total_deleted = 0
    total_failed  = 0

    for service in AURORA_SERVICES:
        conn = None
        deleted, failed, skipped = [], [], []

        try:
            conn  = _connect(service)
            slots = _query_slots(conn)

            for slot in slots:
                slot_name = slot["slot_name"]

                if not _is_dms_slot(slot_name):
                    continue  # DMS prefix 없는 slot은 건드리지 않음

                if slot["active"] or slot["active_pid"] is not None:
                    skipped.append({"slot_name": slot_name, "reason": "active"})
                    logger.info(f"[{service}] 활성 slot 건너뜀: {slot_name}")
                    continue

                if not _is_stale(slot):
                    skipped.append({
                        "slot_name":      slot_name,
                        "reason":         "not_stale",
                        "wal_lag_gb":     slot["wal_lag_gb"],
                        "inactive_hours": slot["inactive_hours"],
                    })
                    logger.info(
                        f"[{service}] 임계값 미달 건너뜀: {slot_name} "
                        f"(WAL {slot['wal_lag_gb']}GB, 비활성 {slot['inactive_hours']}h)"
                    )
                    continue

                try:
                    conn.run(f"SELECT pg_drop_replication_slot('{slot_name}')")
                    logger.info(
                        f"[{service}] slot 삭제: {slot_name} "
                        f"(WAL {slot['wal_lag_gb']}GB, 비활성 {slot['inactive_hours']}h)"
                    )
                    deleted.append({"slot_name": slot_name, "wal_lag_gb": slot["wal_lag_gb"]})
                    total_deleted += 1
                except Exception as e:
                    logger.error(f"[{service}] slot 삭제 실패 ({slot_name}): {e}")
                    failed.append({"slot_name": slot_name, "error": str(e)})
                    total_failed += 1

            results[service] = {"deleted": deleted, "failed": failed, "skipped": skipped}

        except Exception as e:
            logger.error(f"[{service}] DB 접속 실패: {e}")
            results[service] = {"error": str(e)}
            total_failed += 1
        finally:
            if conn:
                try: conn.close()
                except Exception: pass

    logger.info(f"cleanup_stale_slots 완료: 삭제 {total_deleted}개, 실패 {total_failed}개")

    # 삭제 결과 SNS 알림
    if total_deleted > 0 or total_failed > 0:
        notify({
            "status":  "FAILED" if total_failed > 0 else "SUCCESS",
            "message": f"DMS slot cleanup: 삭제 {total_deleted}개, 실패 {total_failed}개",
            "results": results,
        })

    return {
        "action":        "cleanup_stale_slots",
        "results":       results,
        "total_deleted": total_deleted,
        "total_failed":  total_failed,
    }


def notify(event):
    """SNS 알림"""
    sns     = boto3.client("sns", region_name=REGION)
    status  = event.get("status", "INFO")
    subject = f"[DMS Slot Cleanup] {PROJECT_NAME}-{ENVIRONMENT} {status}"
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject,
        Message=json.dumps(event, indent=2, ensure_ascii=False),
    )
    logger.info(f"SNS 알림: {subject}")
    return {"action": "notify", "status": "sent"}


def lambda_handler(event, context):
    action = event.get("action")
    logger.info(f"DMS Slot Cleanup: action={action}")

    dispatch = {
        "list_slots":          list_slots,
        "cleanup_stale_slots": cleanup_stale_slots,
        "notify":              notify,
    }
    handler = dispatch.get(action)
    if not handler:
        raise ValueError(f"알 수 없는 action: {action}. 허용값: {list(dispatch.keys())}")
    return handler(event)

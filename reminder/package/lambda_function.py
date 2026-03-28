"""
purchase_history 알림 Lambda
- 매일 KST 09:00 실행 (EventBridge Scheduler)
- remain_day <= threshold인 purchase_history 조회
- cognito_id → Cognito admin_get_user → 이메일 조회
- SES로 이메일 발송
- reminder_sent = true 업데이트
"""

import os
import json
import logging
import pg8000.native
import boto3
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REGION              = os.environ["AWS_REGION"]
DB_HOST             = os.environ["DB_HOST"]
DB_PORT             = int(os.environ.get("DB_PORT", "5432"))
DB_NAME             = os.environ["DB_NAME"]
DB_USER             = os.environ["DB_USER"]
DB_PASSWORD         = os.environ["DB_PASSWORD"]
USER_POOL_ID        = os.environ["COGNITO_USER_POOL_ID"]
SES_FROM_EMAIL      = os.environ["SES_FROM_EMAIL"]
DAYS_THRESHOLD      = int(os.environ.get("DAYS_THRESHOLD", "30"))


def get_reminder_targets(conn) -> list[dict]:
    """remain_day <= threshold이고 reminder_sent=false인 대상 조회"""
    sql = """
        SELECT
            ph.purchase_id,
            ph.remain_day,
            ph.total_quantity,
            ph.purchased_dt,
            is_supp.cognito_id,
            is_supp.itk_product_name
        FROM purchase_history ph
        JOIN intake_item ii ON ph.item_id = ii.item_id
        JOIN intake_supplements is_supp ON ii.current_id = is_supp.current_id
        WHERE ph.remain_day <= :threshold
          AND (ph.reminder_sent IS NULL OR ph.reminder_sent = false)
    """
    rows = conn.run(sql, threshold=DAYS_THRESHOLD)
    cols = ["purchase_id", "remain_day", "total_quantity", "purchased_dt", "cognito_id", "itk_product_name"]
    return [dict(zip(cols, row)) for row in rows]


def get_email_from_cognito(cognito_client, cognito_id: str) -> str | None:
    """Cognito에서 cognito_id(sub)로 이메일 조회"""
    try:
        resp = cognito_client.admin_get_user(
            UserPoolId=USER_POOL_ID,
            Username=cognito_id
        )
        for attr in resp.get("UserAttributes", []):
            if attr["Name"] == "email":
                return attr["Value"]
    except cognito_client.exceptions.UserNotFoundException:
        logger.warning(f"Cognito user not found: {cognito_id}")
    except Exception as e:
        logger.error(f"Cognito lookup failed for {cognito_id}: {e}")
    return None


def send_reminder_email(ses_client, to_email: str, target: dict):
    """SES로 알림 이메일 발송"""
    product_name = target.get("itk_product_name", "영양제")
    remain_day   = target.get("remain_day", 0)

    subject = f"[CodeCaine] {product_name} 재고 알림"
    body = f"""안녕하세요!

복용 중인 {product_name}의 재고가 {remain_day}일 분량 남았습니다.

제때 재구매하셔서 건강 관리를 이어가세요.

감사합니다.
CodeCaine 팀
"""

    ses_client.send_email(
        Source=SES_FROM_EMAIL,
        Destination={"ToAddresses": [to_email]},
        Message={
            "Subject": {"Data": subject, "Charset": "UTF-8"},
            "Body": {"Text": {"Data": body, "Charset": "UTF-8"}}
        }
    )
    logger.info(f"Email sent to {to_email} for purchase_id={target['purchase_id']}")


def mark_reminder_sent(conn, purchase_ids: list[int]):
    """reminder_sent = true 업데이트"""
    if not purchase_ids:
        return
    for pid in purchase_ids:
        conn.run(
            "UPDATE purchase_history SET reminder_sent = true, updated_at = NOW() WHERE purchase_id = :pid",
            pid=pid
        )
    logger.info(f"Marked {len(purchase_ids)} records as reminder_sent")


def lambda_handler(event, context):
    logger.info(f"Reminder Lambda started at {datetime.utcnow().isoformat()}")

    conn = pg8000.native.Connection(
        host=DB_HOST, port=DB_PORT,
        database=DB_NAME, user=DB_USER, password=DB_PASSWORD,
        ssl_context=True, timeout=10
    )

    cognito = boto3.client("cognito-idp", region_name=REGION)
    ses     = boto3.client("ses", region_name=REGION)

    try:
        targets = get_reminder_targets(conn)
        logger.info(f"Found {len(targets)} reminder targets")

        sent_ids = []
        for target in targets:
            cognito_id = target["cognito_id"]
            email = get_email_from_cognito(cognito, cognito_id)
            if not email:
                logger.warning(f"No email for cognito_id={cognito_id}, skipping")
                continue

            try:
                send_reminder_email(ses, email, target)
                sent_ids.append(target["purchase_id"])
            except Exception as e:
                logger.error(f"Failed to send email to {email}: {e}")

        mark_reminder_sent(conn, sent_ids)
        return {"sent": len(sent_ids), "total_targets": len(targets)}

    finally:
        conn.close()

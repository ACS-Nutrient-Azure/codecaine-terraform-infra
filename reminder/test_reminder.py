import boto3
import os

REGION       = os.environ.get("AWS_REGION", "ap-northeast-2")
USER_POOL_ID = "ap-northeast-2_UxBX0JXke"
FROM_EMAIL   ="noreply@codecaine.store"

def lambda_handler(event, context):
    cognito_id   = "d4384dbc-e0d1-7004-4f8c-b5271c10a0b7"
    product_name = "오메가3"
    remain_day   = 15

    cognito = boto3.client("cognito-idp", region_name=REGION)
    ses     = boto3.client("ses", region_name=REGION)

    # Cognito에서 이메일 조회
    resp = cognito.admin_get_user(UserPoolId=USER_POOL_ID, Username=cognito_id)
    email = next(
        (attr["Value"] for attr in resp["UserAttributes"] if attr["Name"] == "email"),
        None
    )

    if not email:
        return {"status": "no_email", "cognito_id": cognito_id}

    # SES 발송
    ses.send_email(
        Source=FROM_EMAIL,
        Destination={"ToAddresses": [email]},
        Message={
            "Subject": {"Data": f"[CodeCaine] {product_name} 재고 알림", "Charset": "UTF-8"},
            "Body": {"Text": {
                "Data": f"복용 중인 {product_name}의 재고가 {remain_day}일 분량 남았습니다.\n\n제때 재구매하셔서 건강 관리를 이어가세요.\n\nCodeCaine 팀",
                "Charset": "UTF-8"
            }}
        }
    )

    return {"status": "sent", "to": email, "cognito_id": cognito_id}

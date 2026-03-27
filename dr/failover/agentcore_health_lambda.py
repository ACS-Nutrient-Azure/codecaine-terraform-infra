"""
AgentCore Health Check Lambda
EventBridge Scheduled Rule (1분마다) 호출
AgentCore Runtime 상태 확인 → CloudWatch 커스텀 메트릭 발행
"""
import boto3
import os
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REGION       = os.environ["PRIMARY_REGION"]
PROJECT_NAME = os.environ["PROJECT_NAME"]
ENVIRONMENT  = os.environ["ENVIRONMENT"]
CW_NAMESPACE = f"{PROJECT_NAME}/DR"

AGENT_SSM_KEYS = [
    f"/{PROJECT_NAME}/{ENVIRONMENT}/agentcore/analysis-agent/runtime-arn",
    f"/{PROJECT_NAME}/{ENVIRONMENT}/agentcore/chatbot-agent/runtime-arn",
    f"/{PROJECT_NAME}/{ENVIRONMENT}/agentcore/summary-agent/runtime-arn",
]


def lambda_handler(event, context):
    ssm        = boto3.client("ssm", region_name=REGION)
    agentcore  = boto3.client("bedrock-agentcore-control", region_name=REGION)
    cw         = boto3.client("cloudwatch", region_name=REGION)

    healthy_count = 0
    total_count   = len(AGENT_SSM_KEYS)

    for ssm_key in AGENT_SSM_KEYS:
        try:
            param = ssm.get_parameter(Name=ssm_key)
            runtime_arn = param["Parameter"]["Value"]

            if runtime_arn == "pending":
                logger.warning(f"Runtime not yet created: {ssm_key}")
                continue

            runtime_id = runtime_arn.split("/")[-1]
            resp = agentcore.get_agent_runtime(agentRuntimeId=runtime_id)
            status = resp.get("status", "UNKNOWN")

            if status == "READY":
                healthy_count += 1
                logger.info(f"Healthy: {ssm_key} → {status}")
            else:
                logger.warning(f"Unhealthy: {ssm_key} → {status}")

        except Exception as e:
            logger.error(f"Health check failed for {ssm_key}: {e}")

    # 커스텀 메트릭 발행 (1 = 정상, 0 = 장애)
    is_healthy = 1 if healthy_count == total_count else 0

    cw.put_metric_data(
        Namespace=CW_NAMESPACE,
        MetricData=[{
            "MetricName": "AgentCoreHealthy",
            "Value": is_healthy,
            "Unit": "Count",
            "Dimensions": [
                {"Name": "Region", "Value": REGION},
                {"Name": "Environment", "Value": ENVIRONMENT},
            ]
        }]
    )

    logger.info(f"AgentCore health: {healthy_count}/{total_count} → metric={is_healthy}")
    return {"healthy": healthy_count, "total": total_count}

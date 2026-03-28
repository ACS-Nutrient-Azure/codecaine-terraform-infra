project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-2"

# FIS 실험 중단 조건: DR Composite Alarm (복합 장애 감지 시 실험 즉시 중단)
# 실제 ARN으로 교체 필요
stop_condition_alarm_arn = "arn:aws:cloudwatch:ap-northeast-2:620758375333:alarm:cdci-prd-DR-TRIGGER"

notification_email = "your-team@example.com"

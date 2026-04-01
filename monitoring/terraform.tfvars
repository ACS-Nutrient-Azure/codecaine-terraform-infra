project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-2"

# grafana_api_key는 민감 정보이므로 tfvars에 직접 기입하지 않습니다.
# 아래 방법 중 하나로 제공하세요:
#   export TF_VAR_grafana_api_key="<service-account-token>"
#   또는 terraform apply -var="grafana_api_key=<token>"

# alarm_email은 민감 정보이므로 환경변수로 제공 권장:
#   export TF_VAR_alarm_email="your-alert@example.com"
#   또는 terraform apply -var="alarm_email=your-alert@example.com"

# Phase 2 민감 변수는 환경변수로 제공:
#   export TF_VAR_ses_sender_email="rokalsh@icloud.com"
#   export TF_VAR_alarm_recipient_email="rokalsh@icloud.com"

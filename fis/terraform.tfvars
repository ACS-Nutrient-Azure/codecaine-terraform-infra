project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-2"

# FIS 실험 중단 조건: DR Composite Alarm이 apply된 경우 ARN 입력
# 비워두면 더미 알람이 자동 생성됨
stop_condition_alarm_arn = ""

notification_email = "ahldb10@gmail.com"

# ── ECS 태스크 ARN (실험 전 현재 ARN으로 업데이트) ──────────────
# 조회 명령어:
# aws ecs list-tasks --cluster cdci-prd-cluster --service-name cdci-prd-<service>-service --region ap-northeast-2
ecs_task_arns = {
  users    = [
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/4271e0b6eafd4bee9fcfbbb2fa066030",
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/47392d78c83f45c4a51781ab4bfe5933"
    ]
  history  = [
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/0b59847c821f481688bae38f8379ce5a",
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/e38393b46224441e887eadfcac35a9ca"
    ]
  chatbot  = [
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/7605dc708ac947a0b3a8a63b6e6effc6", 
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/46455548b6ab43149b23c67952077e3a"
    ]
  analysis = [
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/61c81c31ac214c758b7f24a78b205ed9",
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/2929a01d05544bcfac8a6fe6c5a257e5"
    ]
  frontend = [
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/6ede4c4ff2eb4d55943b3a8655a50b47",
    "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/bcb0fcd4a67549b18d5f3fb795fc8c8a"
    ]
}

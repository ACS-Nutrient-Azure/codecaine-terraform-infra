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
  users    = ["arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/1352f222158041bbb0a97044c99d14d8"]
  history  = ["arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/3257e8f3b8ab4306848d1952e3dc4c91"]
  chatbot  = ["arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/7555c0eae7cd4d93b966b1157a77c73f"]
  analysis = ["arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/6bdfbb1971724547930e685c518207dd"]
  frontend = ["arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/3117db479b36482b890b60fbe637e2c0", "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/4aa928dcc6664d9cb7eca2a4e64b917b"]
}

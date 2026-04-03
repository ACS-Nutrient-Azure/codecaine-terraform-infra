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
  users    = "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/06d8fb43acfc4cc3945d44e9a73f0761"
  history  = "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/cebb7efcdbea41c2962ae885562e32ea"
  chatbot  = "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/2dd855a322ca4c7693a3a6a54fefd83a"
  analysis = "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/e832407db2ca450f839d032a51f11b4f"
  frontend = "arn:aws:ecs:ap-northeast-2:620758375333:task/cdci-prd-cluster/d7bc941478f94952aba1bb003819a796"
}

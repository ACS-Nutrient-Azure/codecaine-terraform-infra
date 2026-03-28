# ── 레이어별 장애 감지 CloudWatch Alarms ─────────────────────────
#
# 감지 레이어:
#   1. ECS/ALB: ALB UnhealthyHostCount (5개 서비스 중 3개 이상)
#   2. Aurora:  RDS EventSubscription (failover/failure 이벤트)
#               + DatabaseConnections = 0 (4개 클러스터 중 2개 이상)
#   3. AgentCore: EventBridge Scheduled Rule → Health Check Lambda
#
# Composite Alarm: 위 레이어 중 2개 이상 동시 ALARM → DR 트리거
# (단일 레이어 장애는 자가 복구 대기, 복합 장애 = 리전 장애로 판단)

locals {
  alb_arn_suffix = data.terraform_remote_state.compute.outputs.alb_arn_suffix

  # Aurora 클러스터 식별자
  aurora_clusters = {
    cluster1 = "${var.project_name}-${var.environment}-users-cluster"
    cluster2 = "${var.project_name}-${var.environment}-history-cluster"
    cluster3 = "${var.project_name}-${var.environment}-analysis-cluster"
    cluster4 = "${var.project_name}-${var.environment}-chatbot-cluster"
  }
}

# ── SNS Topic (DR 알림) ───────────────────────────────────────────

resource "aws_sns_topic" "dr_alert" {
  name = "${var.project_name}-${var.environment}-dr-alert"
}

resource "aws_sns_topic_subscription" "dr_alert_email" {
  topic_arn = aws_sns_topic.dr_alert.arn
  protocol  = "email"
  endpoint  = var.alarm_sns_email
}

# ── Layer 1: ECS/ALB Alarm ────────────────────────────────────────
# 5개 서비스 Target Group의 UnhealthyHostCount 합산
# 각 서비스별 Alarm 생성 후 Composite로 묶음

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  for_each = toset(["users", "history", "chatbot", "analysis", "frontend"])

  alarm_name          = "${var.project_name}-${var.environment}-dr-alb-unhealthy-${each.key}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3 # 3회 연속 (90초)
  metric_name         = "UnhealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 30
  statistic           = "Maximum"
  threshold           = 1

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
    TargetGroup  = data.terraform_remote_state.compute.outputs.target_group_arn_suffixes[each.key]
  }

  alarm_description  = "DR: ${each.key} 서비스 unhealthy host 감지"
  treat_missing_data = "breaching"
}

# 5개 중 3개 이상 ALARM → ECS 레이어 장애로 판단
resource "aws_cloudwatch_composite_alarm" "ecs_layer_failure" {
  alarm_name = "${var.project_name}-${var.environment}-dr-ecs-layer-failure"

  alarm_rule = join(" OR ", [
    # 3개 이상 조합 (users+history+chatbot, users+history+analysis, ...)
    # 핵심 백엔드 3개(users, history, chatbot) 동시 장애로 단순화
    "ALARM(${aws_cloudwatch_metric_alarm.alb_unhealthy["users"].alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.alb_unhealthy["history"].alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.alb_unhealthy["chatbot"].alarm_name})"
  ])

  alarm_description = "DR: ECS 레이어 장애 (핵심 서비스 3개 동시 unhealthy)"
}

# ── Layer 2: Aurora Alarm ─────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  for_each = local.aurora_clusters

  alarm_name          = "${var.project_name}-${var.environment}-dr-aurora-conn-${each.key}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0

  dimensions = { DBClusterIdentifier = each.value }

  alarm_description  = "DR: Aurora ${each.key} 연결 없음"
  treat_missing_data = "breaching"
}

# 4개 클러스터 중 2개 이상 연결 없음 → Aurora 레이어 장애
resource "aws_cloudwatch_composite_alarm" "aurora_layer_failure" {
  alarm_name = "${var.project_name}-${var.environment}-dr-aurora-layer-failure"

  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.aurora_connections["cluster1"].alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.aurora_connections["cluster2"].alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.aurora_connections["cluster1"].alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.aurora_connections["cluster3"].alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.aurora_connections["cluster2"].alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.aurora_connections["cluster3"].alarm_name})",
  ])

  alarm_description = "DR: Aurora 레이어 장애 (2개 이상 클러스터 연결 불가)"
}

# RDS Event Subscription → SNS → EventBridge (즉각 감지용)
resource "aws_db_event_subscription" "aurora_failover" {
  name      = "${var.project_name}-${var.environment}-dr-aurora-events"
  sns_topic = aws_sns_topic.dr_alert.arn

  source_type = "db-cluster"
  event_categories = [
    "failover",
    "failure",
    "maintenance",
  ]

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-AURORA-EVENTS" }
}

# ── Layer 3: AgentCore Health Check ──────────────────────────────
# EventBridge Scheduled Rule → Health Check Lambda (1분마다)
# Lambda가 AgentCore Runtime 상태 확인 후 CW 커스텀 메트릭 발행

resource "aws_cloudwatch_metric_alarm" "agentcore_health" {
  alarm_name          = "${var.project_name}-${var.environment}-dr-agentcore-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3 # 3분 연속 실패
  metric_name         = "AgentCoreHealthy"
  namespace           = "${var.project_name}/DR"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1

  alarm_description  = "DR: AgentCore Runtime 헬스체크 실패"
  treat_missing_data = "breaching"
}

# ── Composite Alarm: DR 트리거 조건 ──────────────────────────────
# ECS 레이어 OR Aurora 레이어 장애 → DR 트리거
# (AgentCore 단독 장애는 ECS/Aurora 정상이면 DR 불필요)

resource "aws_cloudwatch_composite_alarm" "dr_trigger" {
  alarm_name = "${var.project_name}-${var.environment}-DR-TRIGGER"

  alarm_rule = join(" OR ", [
    # ECS + Aurora 동시 장애 (리전 레벨 장애)
    "ALARM(${aws_cloudwatch_composite_alarm.ecs_layer_failure.alarm_name}) AND ALARM(${aws_cloudwatch_composite_alarm.aurora_layer_failure.alarm_name})",
    # Aurora 장애 + AgentCore 장애
    "ALARM(${aws_cloudwatch_composite_alarm.aurora_layer_failure.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.agentcore_health.alarm_name})",
    # ECS 전체 + AgentCore 장애
    "ALARM(${aws_cloudwatch_composite_alarm.ecs_layer_failure.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.agentcore_health.alarm_name})",
  ])

  alarm_description = "DR TRIGGER: 복합 레이어 장애 감지 → 도쿄 Failover 실행"

  alarm_actions = [aws_sns_topic.dr_alert.arn]
  ok_actions    = [aws_sns_topic.dr_alert.arn]
}

# ── EventBridge: DR Composite Alarm OK 전환 → Failback 트리거 ─────
# DR-TRIGGER Alarm이 ALARM → OK로 전환될 때 dr-failback-orchestrator 실행
# (서울 리전 장애 해소 감지)

resource "aws_cloudwatch_event_rule" "dr_failback_trigger" {
  name        = "${var.project_name}-${var.environment}-dr-failback-trigger"
  description = "DR Composite Alarm OK 전환 → Failback Step Functions 실행"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName     = ["${var.project_name}-${var.environment}-DR-TRIGGER"]
      state         = { value = ["OK"] }
      previousState = { value = ["ALARM"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "dr_failback_step_functions" {
  rule      = aws_cloudwatch_event_rule.dr_failback_trigger.name
  target_id = "dr-failback-step-functions"
  arn       = aws_sfn_state_machine.dr_failback_orchestrator.arn
  role_arn  = aws_iam_role.eventbridge_sfn.arn
}

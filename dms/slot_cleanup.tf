# ── DMS Replication Slot Cleanup ─────────────────────────────────
#
# 삭제 조건 (모두 충족):
#   1. DMS prefix (awsdms_, dms_)
#   2. active = false + active_pid = NULL (연결 없음)
#   3. WAL lag > 5GB  OR  비활성 시간 > 2시간
#
# 구성:
#   - Lambda (VPC 내부, Aurora 직접 접속)
#   - EventBridge: 30분마다 list_slots → 정리 대상 있으면 cleanup 자동 호출
#   - CloudWatch Alarm: WAL lag > 10GB → SNS 알림

# ── SNS Topic ─────────────────────────────────────────────────────

resource "aws_sns_topic" "dms_alert" {
  name = "${local.name_prefix}-dms-alert"
}

# ── Lambda 패키징 ─────────────────────────────────────────────────

data "archive_file" "slot_cleanup" {
  type        = "zip"
  source_file = "${path.module}/slot_cleanup_lambda.py"
  output_path = "${path.module}/files/slot_cleanup.zip"
}

# ── IAM Role ──────────────────────────────────────────────────────

resource "aws_iam_role" "slot_cleanup_lambda" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DMS-SLOT-CLEANUP-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "slot_cleanup_vpc" {
  role       = aws_iam_role.slot_cleanup_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "slot_cleanup_policy" {
  name = "dms-slot-cleanup-policy"
  role = aws_iam_role.slot_cleanup_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Secrets Manager: DB 자격증명 (dms/main.tf와 동일한 secret 이름 패턴)
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          for svc in ["users", "history", "analysis", "chatbot"] :
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-${svc}-cluster-secret*"
        ]
      },
      # SNS 알림
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.dms_alert.arn]
      },
      # CloudWatch 커스텀 메트릭 발행
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = ["*"]
      },
      # 자기 자신 비동기 호출 (list_slots → cleanup_stale_slots)
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = ["arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${lower("${local.name_prefix}-dms-slot-cleanup")}"]
      },
    ]
  })
}

# ── Security Group (Lambda → Aurora 5432) ─────────────────────────

resource "aws_security_group" "slot_cleanup_lambda" {
  name        = "${local.name_prefix}-dms-slot-cleanup-sg"
  description = "DMS slot cleanup Lambda to Aurora PostgreSQL"
  vpc_id      = local.vpc_id

  egress {
    description = "Aurora PostgreSQL 5432"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "HTTPS for Secrets Manager, SNS, CloudWatch, Lambda API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${upper(local.name_prefix)}-DMS-SLOT-CLEANUP-SG" }
}

# ── Lambda 함수 ───────────────────────────────────────────────────

resource "aws_lambda_function" "slot_cleanup" {
  function_name    = lower("${local.name_prefix}-dms-slot-cleanup")
  runtime          = "python3.12"
  handler          = "slot_cleanup_lambda.lambda_handler"
  role             = aws_iam_role.slot_cleanup_lambda.arn
  timeout          = 300
  filename         = data.archive_file.slot_cleanup.output_path
  source_code_hash = data.archive_file.slot_cleanup.output_base64sha256

  vpc_config {
    subnet_ids         = local.private_db_subnet_ids
    security_group_ids = [aws_security_group.slot_cleanup_lambda.id]
  }

  environment {
    variables = {
      REGION        = var.region
      PROJECT_NAME  = var.project_name
      ENVIRONMENT   = var.environment
      SNS_TOPIC_ARN = aws_sns_topic.dms_alert.arn
    }
  }

  tags = { Name = "${upper(local.name_prefix)}-DMS-SLOT-CLEANUP" }
}

# ── EventBridge: 30분마다 list_slots 실행 ─────────────────────────

resource "aws_cloudwatch_event_rule" "slot_cleanup_schedule" {
  name                = "${local.name_prefix}-dms-slot-cleanup-schedule"
  description         = "DMS replication slot WAL lag 모니터링 (30분마다)"
  schedule_expression = "rate(30 minutes)"
}

resource "aws_cloudwatch_event_target" "slot_cleanup_schedule" {
  rule      = aws_cloudwatch_event_rule.slot_cleanup_schedule.name
  target_id = "dms-slot-cleanup-lambda"
  arn       = aws_lambda_function.slot_cleanup.arn
  input     = jsonencode({ action = "list_slots" })
}

resource "aws_lambda_permission" "slot_cleanup_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slot_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.slot_cleanup_schedule.arn
}

# ── CloudWatch Alarm: WAL lag > 10GB → SNS 알림 ───────────────────

resource "aws_cloudwatch_metric_alarm" "dms_wal_lag_high" {
  alarm_name          = "${local.name_prefix}-dms-wal-lag-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MaxWalLagBytes"
  namespace           = "${var.project_name}/DMS"
  period              = 1800
  statistic           = "Maximum"
  threshold           = 10737418240 # 10GB

  alarm_description  = "DMS replication slot WAL lag > 10GB: 디스크 풀 위험"
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.dms_alert.arn]
  ok_actions    = [aws_sns_topic.dms_alert.arn]

  tags = { Name = "${upper(local.name_prefix)}-DMS-WAL-LAG-HIGH" }
}

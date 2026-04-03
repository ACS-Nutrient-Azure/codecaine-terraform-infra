# ── FIS 실험 결과 로그 그룹 ───────────────────────────────────────

resource "aws_cloudwatch_log_group" "fis" {
  name              = "/fis/${var.project_name}-${var.environment}"
  retention_in_days = 3

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-FIS-LOGS"
  }
}

# ── FIS 실험 결과 SNS 알림 ────────────────────────────────────────

resource "aws_sns_topic" "fis_notifications" {
  name = "${var.project_name}-${var.environment}-fis-notifications"
}

resource "aws_sns_topic_subscription" "fis_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.fis_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

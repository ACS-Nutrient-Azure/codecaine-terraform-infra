# EventBridge Scheduler: 매일 KST 09:00 (UTC 00:00) 실행

resource "aws_scheduler_schedule" "reminder" {
  name       = "${var.project_name}-${var.environment}-purchase-reminder"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = "Asia/Seoul"

  target {
    arn      = aws_lambda_function.reminder.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      source = "scheduled"
    })

    retry_policy {
      maximum_retry_attempts = 2
    }
  }
}

resource "aws_lambda_permission" "scheduler" {
  statement_id  = "AllowSchedulerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reminder.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.reminder.arn
}

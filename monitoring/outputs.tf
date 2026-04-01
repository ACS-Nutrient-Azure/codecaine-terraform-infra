output "grafana_workspace_id" {
  description = "Grafana workspace ID"
  value       = aws_grafana_workspace.main.id
}

output "grafana_workspace_url" {
  description = "Grafana workspace endpoint URL"
  value       = "https://${aws_grafana_workspace.main.endpoint}"
}

output "grafana_role_arn" {
  description = "IAM role ARN used by Grafana"
  value       = aws_iam_role.grafana.arn
}

# ============================================================
# SNS Topic ARN 출력
# ============================================================

output "sns_topic_arn_email" {
  description = "SNS topic ARN for direct email notifications (Phase 1)"
  value       = aws_sns_topic.alarms_email.arn
}

output "sns_topic_arn_lambda" {
  description = "SNS topic ARN for Lambda enrichment (Phase 2)"
  value       = aws_sns_topic.alarms_lambda.arn
}

output "lambda_function_arn" {
  description = "Lambda function ARN for alarm enrichment (Phase 2)"
  value       = aws_lambda_function.alarm_enricher.arn
}

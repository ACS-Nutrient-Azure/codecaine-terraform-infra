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

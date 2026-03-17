output "github_actions_role_arn" {
  description = "GitHub Actions IAM role ARN"
  value       = var.create_github_oidc ? aws_iam_role.github_actions[0].arn : ""
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = var.create_github_oidc ? aws_iam_openid_connect_provider.github[0].arn : ""
}

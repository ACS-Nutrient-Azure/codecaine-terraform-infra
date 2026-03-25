output "ecr_repository_url" {
  description = "ECR 레포 URL (GitHub Actions deploy.yml에서 사용)"
  value       = data.terraform_remote_state.ecr.outputs.agent_repository_urls["summary-agent"]
}

output "github_actions_role_arn" {
  description = "GitHub Secrets AWS_DEPLOY_ROLE_ARN에 설정"
  value       = aws_iam_role.github_actions.arn
}

output "agentcore_runtime_role_arn" {
  description = "AgentCore Runtime Role ARN"
  value       = aws_iam_role.agentcore_runtime.arn
}

output "agentcore_runtime_arn" {
  description = "AgentCore Runtime ARN"
  value       = jsondecode(aws_lambda_invocation.agentcore_runtime.result)["runtime_arn"]
}

# output "agentcore_runtime_arn" {
#   description = "App 환경변수 AGENTCORE_RUNTIME_ARN에 설정"
#   value       = aws_bedrockagentcore_runtime.analysis_agent.agent_runtime_arn
# }

output "ecr_repository_url" {
  description = "ECR 레포 URL (GitHub Actions deploy.yml에서 사용)"
  value       = aws_ecr_repository.analysis_agent.repository_url
}

output "github_actions_role_arn" {
  description = "GitHub Secrets AWS_DEPLOY_ROLE_ARN에 설정"
  value       = aws_iam_role.github_actions.arn
}

output "lambda_function_arn" {
  description = "Lambda ARN"
  value       = aws_lambda_function.nutrient_calc.arn
}

output "agentcore_runtime_role_arn" {
  description = "AgentCore Runtime Role ARN"
  value       = aws_iam_role.agentcore_runtime.arn
}

output "lambda_function_name" {
  description = "AgentCore Provisioner Lambda 함수명 (각 에이전트 모듈에서 참조)"
  value       = aws_lambda_function.provisioner.function_name
}

output "lambda_function_arn" {
  description = "AgentCore Provisioner Lambda ARN"
  value       = aws_lambda_function.provisioner.arn
}

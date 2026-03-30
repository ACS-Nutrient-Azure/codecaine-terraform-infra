output "memory_id" {
  description = "AgentCore Memory ID"
  value       = awscc_bedrockagentcore_memory.chatbot_session.memory_id
  sensitive   = true
}

output "memory_arn" {
  description = "AgentCore Memory ARN"
  value       = awscc_bedrockagentcore_memory.chatbot_session.memory_arn
}

output "memory_ssm_key" {
  description = "SSM Parameter key for memory_id"
  value       = aws_ssm_parameter.memory_id.name
}

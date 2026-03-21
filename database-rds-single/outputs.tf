output "users_endpoint" {
  value = aws_db_instance.users.address
}

output "history_endpoint" {
  value = aws_db_instance.history.address
}

output "analysis_endpoint" {
  value = aws_db_instance.analysis.address
}

output "users_secret_arn" {
  value = aws_secretsmanager_secret.users.arn
}

output "history_secret_arn" {
  value = aws_secretsmanager_secret.history.arn
}

output "analysis_secret_arn" {
  value = aws_secretsmanager_secret.analysis.arn
}

output "chatbot_endpoint" {
  value = aws_db_instance.chatbot.address
}

output "chatbot_secret_arn" {
  value = aws_secretsmanager_secret.chatbot.arn
}

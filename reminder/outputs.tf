output "lambda_function_name" {
  value = aws_lambda_function.reminder.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.reminder.arn
}

output "scheduler_arn" {
  value = aws_scheduler_schedule.reminder.arn
}

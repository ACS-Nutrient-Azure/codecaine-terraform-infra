output "dynamodb_table_names" {
  description = "DynamoDB table names"
  value = {
    for k, v in aws_dynamodb_table.main : k => v.name
  }
}

output "dynamodb_table_arns" {
  description = "DynamoDB table ARNs"
  value = {
    for k, v in aws_dynamodb_table.main : k => v.arn
  }
}

output "dynamodb_table_stream_arns" {
  description = "DynamoDB table stream ARNs"
  value = {
    for k, v in aws_dynamodb_table.main : k => v.stream_arn
  }
}

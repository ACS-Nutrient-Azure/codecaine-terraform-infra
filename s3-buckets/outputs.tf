output "alb_logs_bucket_name" {
  description = "ALB logs S3 bucket name"
  value       = aws_s3_bucket.alb_logs.bucket
}

output "alb_logs_bucket_arn" {
  description = "ALB logs S3 bucket ARN"
  value       = aws_s3_bucket.alb_logs.arn
}

output "codef_data_bucket_name" {
  description = "CODEF API data S3 bucket name"
  value       = aws_s3_bucket.codef_data.bucket
}

output "codef_data_bucket_arn" {
  description = "CODEF API data S3 bucket ARN"
  value       = aws_s3_bucket.codef_data.arn
}

output "knowledgebase_bucket_name" {
  description = "Knowledge Base S3 bucket name"
  value       = aws_s3_bucket.knowledgebase.bucket
}

output "knowledgebase_bucket_arn" {
  description = "Knowledge Base S3 bucket ARN"
  value       = aws_s3_bucket.knowledgebase.arn
}

output "monitoring_bucket_name" {
  description = "Monitoring S3 bucket name"
  value       = aws_s3_bucket.monitoring.bucket
}

output "monitoring_bucket_arn" {
  description = "Monitoring S3 bucket ARN"
  value       = aws_s3_bucket.monitoring.arn
}

output "chatbot_json_bucket_name" {
  description = "Chatbot JSON S3 bucket name"
  value       = aws_s3_bucket.chatbot_json.bucket
}

output "chatbot_json_bucket_arn" {
  description = "Chatbot JSON S3 bucket ARN"
  value       = aws_s3_bucket.chatbot_json.arn
}

output "cloudtrail_bucket_name" {
  description = "CloudTrail S3 bucket name"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_bucket_arn" {
  description = "CloudTrail S3 bucket ARN"
  value       = aws_s3_bucket.cloudtrail.arn
}

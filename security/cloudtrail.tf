# CloudTrail 설정
# S3 버킷은 s3-buckets 모듈에서 관리

# S3 버킷 참조
data "terraform_remote_state" "s3_buckets" {
  backend = "local"

  config = {
    path = "../s3-buckets/terraform.tfstate"
  }
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}-${var.environment}"
  retention_in_days = 90

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-CLOUDTRAIL-LOGS"
  }
}

# IAM Role for CloudTrail CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-CLOUDTRAIL-CLOUDWATCH-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-CLOUDTRAIL-CLOUDWATCH-ROLE"
  }
}

# IAM Policy for CloudTrail CloudWatch Logs
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-CLOUDTRAIL-CLOUDWATCH-POLICY"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${var.environment}-trail"
  s3_bucket_name                = data.terraform_remote_state.s3_buckets.outputs.cloudtrail_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-TRAIL"
  }

  depends_on = [
    aws_iam_role_policy.cloudtrail_cloudwatch
  ]
}

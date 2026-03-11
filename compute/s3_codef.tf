# S3 Bucket for CODEF API Response Data
# CODEF API 호출 결과를 JSON 형식으로 저장

resource "aws_s3_bucket" "codef_data" {
  bucket = "${var.project_name}-${var.environment}-codef-data"

  tags = {
    Name        = "${var.project_name}-${var.environment}-codef-data"
    Purpose     = "CODEF API Response Storage"
    DataType    = "JSON"
    Sensitivity = "High"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  rule {
    id     = "delete-old-data"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # 30일 후 삭제 (스토리지 클래스 변경 없이 바로 삭제)
    expiration {
      days = 30
    }
  }

  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 Bucket Policy - ECS Tasks만 접근 가능
resource "aws_s3_bucket_policy" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTasksAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task_execution.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.codef_data.arn,
          "${aws_s3_bucket.codef_data.arn}/*"
        ]
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.codef_data.arn,
          "${aws_s3_bucket.codef_data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# S3 Bucket Logging (선택사항)
resource "aws_s3_bucket_logging" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  target_bucket = aws_s3_bucket.codef_data.id
  target_prefix = "access-logs/"
}

# Output
output "codef_s3_bucket_name" {
  description = "CODEF API data S3 bucket name"
  value       = aws_s3_bucket.codef_data.bucket
}

output "codef_s3_bucket_arn" {
  description = "CODEF API data S3 bucket ARN"
  value       = aws_s3_bucket.codef_data.arn
}

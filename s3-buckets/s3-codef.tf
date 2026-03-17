# S3 Bucket for CODEF API Response Data
resource "aws_s3_bucket" "codef_data" {
  bucket = "${var.project_name}-${var.environment}-codef-data"

  tags = {
    Name        = "${upper(var.project_name)}-${upper(var.environment)}-CODEF-DATA"
    Purpose     = "CODEF API Response Storage"
    DataType    = "JSON"
    Sensitivity = "High"
  }
}

resource "aws_s3_bucket_versioning" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  rule {
    id     = "delete-old-data"
    status = "Enabled"

    filter {
      prefix = ""
    }

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

resource "aws_s3_bucket_policy" "codef_data" {
  count  = var.ecs_task_execution_role_arn != "" ? 1 : 0
  bucket = aws_s3_bucket.codef_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTasksAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.ecs_task_execution_role_arn
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

resource "aws_s3_bucket_logging" "codef_data" {
  bucket = aws_s3_bucket.codef_data.id

  target_bucket = aws_s3_bucket.codef_data.id
  target_prefix = "access-logs/"
}

# S3 Bucket for Monitoring
resource "aws_s3_bucket" "monitoring" {
  bucket = "${var.project_name}-${var.environment}-monitoring"

  tags = {
    Name        = "${upper(var.project_name)}-${upper(var.environment)}-MONITORING"
    Purpose     = "Monitoring Data Storage"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "monitoring" {
  bucket = aws_s3_bucket.monitoring.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "monitoring" {
  bucket = aws_s3_bucket.monitoring.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "monitoring" {
  bucket = aws_s3_bucket.monitoring.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "monitoring" {
  bucket = aws_s3_bucket.monitoring.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

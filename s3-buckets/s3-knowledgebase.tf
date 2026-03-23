# S3 Bucket for Knowledge Base
resource "aws_s3_bucket" "knowledgebase" {
  bucket = "${var.project_name}-${var.environment}-knowledgebase"

  tags = {
    Name        = "${upper(var.project_name)}-${upper(var.environment)}-KNOWLEDGEBASE"
    Purpose     = "Knowledge Base Data Storage"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "knowledgebase" {
  bucket = aws_s3_bucket.knowledgebase.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "knowledgebase" {
  bucket = aws_s3_bucket.knowledgebase.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "knowledgebase" {
  bucket = aws_s3_bucket.knowledgebase.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "knowledgebase" {
  bucket = aws_s3_bucket.knowledgebase.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

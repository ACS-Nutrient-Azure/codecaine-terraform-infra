# S3 Bucket for Chatbot JSON Data
# chatbot 서비스가 JSON 파일을 저장하는 버킷

resource "aws_s3_bucket" "chatbot_json" {
  bucket = lower("${var.project_name}-${var.environment}-chatbot-json")

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-CHATBOT-JSON"
    Service = "chatbot"
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "chatbot_json" {
  bucket = aws_s3_bucket.chatbot_json.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "chatbot_json" {
  bucket = aws_s3_bucket.chatbot_json.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "chatbot_json" {
  bucket = aws_s3_bucket.chatbot_json.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Policy - JSON 파일 관리
resource "aws_s3_bucket_lifecycle_configuration" "chatbot_json" {
  bucket = aws_s3_bucket.chatbot_json.id

  rule {
    id     = "delete-old-json"
    status = "Enabled"

    expiration {
      days = 90 # 90일 후 삭제
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# CORS Configuration (필요시)
resource "aws_s3_bucket_cors_configuration" "chatbot_json" {
  bucket = aws_s3_bucket.chatbot_json.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

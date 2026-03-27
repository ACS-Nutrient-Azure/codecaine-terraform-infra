terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key     = "dr/s3-replication/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

# Primary 리전 (서울) - 복제 규칙 설정
provider "aws" {
  region = var.primary_region
  default_tags {
    tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform", DR = "true" }
  }
}

# DR 리전 (도쿄) - 대상 버킷 생성
provider "aws" {
  alias  = "dr"
  region = var.dr_region
  default_tags {
    tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform", DR = "true" }
  }
}

data "aws_caller_identity" "current" {}

# ── DR 대상 버킷 (도쿄) ───────────────────────────────────────────

locals {
  # DR 복제 대상 버킷 목록 (knowledgebase, chatbot-json, codef-data)
  # alb-logs, cloudtrail, monitoring은 복제 불필요
  replicated_buckets = {
    knowledgebase = "${var.project_name}-${var.environment}-knowledgebase"
    chatbot_json  = "${var.project_name}-${var.environment}-chatbot-json"
    codef_data    = "${var.project_name}-${var.environment}-codef-data"
  }
}

resource "aws_s3_bucket" "dr" {
  for_each = local.replicated_buckets
  provider = aws.dr
  bucket   = "${each.value}-dr"
  tags     = { Name = upper("${each.value}-dr"), DR = "true" }
}

resource "aws_s3_bucket_versioning" "dr" {
  for_each = local.replicated_buckets
  provider = aws.dr
  bucket   = aws_s3_bucket.dr[each.key].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dr" {
  for_each = local.replicated_buckets
  provider = aws.dr
  bucket   = aws_s3_bucket.dr[each.key].id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "dr" {
  for_each                = local.replicated_buckets
  provider                = aws.dr
  bucket                  = aws_s3_bucket.dr[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Replication IAM Role ──────────────────────────────────────────

resource "aws_iam_role" "s3_replication" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-S3-REPLICATION-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "s3_replication" {
  name = "s3-replication-policy"
  role = aws_iam_role.s3_replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = [
          for bucket_name in values(local.replicated_buckets) :
          "arn:aws:s3:::${bucket_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = [
          for bucket_name in values(local.replicated_buckets) :
          "arn:aws:s3:::${bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = [
          for key in keys(local.replicated_buckets) :
          "${aws_s3_bucket.dr[key].arn}/*"
        ]
      }
    ]
  })
}

# ── Source 버킷에 Replication 규칙 추가 ──────────────────────────
# knowledgebase

resource "aws_s3_bucket_replication_configuration" "knowledgebase" {
  bucket = "${var.project_name}-${var.environment}-knowledgebase"
  role   = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.dr["knowledgebase"].arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket_versioning.dr]
}

resource "aws_s3_bucket_replication_configuration" "chatbot_json" {
  bucket = "${var.project_name}-${var.environment}-chatbot-json"
  role   = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.dr["chatbot_json"].arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket_versioning.dr]
}

resource "aws_s3_bucket_replication_configuration" "codef_data" {
  bucket = "${var.project_name}-${var.environment}-codef-data"
  role   = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.dr["codef_data"].arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket_versioning.dr]
}

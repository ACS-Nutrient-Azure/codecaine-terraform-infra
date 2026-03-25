terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key     = "compute/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "compute-cluster"
    }
  }
}

# 선택적 의존성: 기존 VPC 사용 시에만 참조
data "terraform_remote_state" "foundation" {
  count   = var.use_existing_vpc ? 1 : 0
  backend = "s3"

  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "foundation/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ECR 모듈 참조
data "terraform_remote_state" "ecr" {
  backend = "s3"

  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "ecr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# S3 버킷 참조
data "terraform_remote_state" "s3_buckets" {
  backend = "s3"

  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "s3-buckets/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Security 모듈 참조 (Route53 Zone ID, ACM Certificate ARN)
data "terraform_remote_state" "security" {
  backend = "s3"

  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# AgentCore analysis-agent 참조
data "terraform_remote_state" "analysis_agent" {
  backend = "s3"

  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "analysis-agent-infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

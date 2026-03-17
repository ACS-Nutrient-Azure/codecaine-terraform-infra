terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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
  backend = "local"

  config = {
    path = "../foundation/terraform.tfstate"
  }
}

# ECR 모듈 참조
data "terraform_remote_state" "ecr" {
  backend = "local"

  config = {
    path = "../ecr/terraform.tfstate"
  }
}

# S3 버킷 참조
data "terraform_remote_state" "s3_buckets" {
  backend = "local"

  config = {
    path = "../s3-buckets/terraform.tfstate"
  }
}

# Security 모듈 참조 (Route53 Zone ID, ACM Certificate ARN)
data "terraform_remote_state" "security" {
  backend = "local"

  config = {
    path = "../security/terraform.tfstate"
  }
}

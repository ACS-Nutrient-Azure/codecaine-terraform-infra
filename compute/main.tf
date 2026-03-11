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

# 선택적 의존성: 기존 ECR 사용 시에만 참조
data "terraform_remote_state" "storage" {
  count   = var.use_existing_ecr ? 1 : 0
  backend = "local"

  config = {
    path = "../storage/terraform.tfstate"
  }
}

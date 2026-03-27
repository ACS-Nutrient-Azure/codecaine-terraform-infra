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
    key     = "dr/ecr-replication/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

# Primary 리전에서 설정 (ECR Replication은 source 리전에서 구성)
provider "aws" {
  region = var.primary_region
}

data "aws_caller_identity" "current" {}

variable "primary_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "dr_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project_name" { type = string }
variable "environment" { type = string }

# ECR Cross-Region Replication
# 서비스 이미지(5개) + 에이전트 이미지(4개) 모두 도쿄로 복제
resource "aws_ecr_replication_configuration" "dr" {
  replication_configuration {
    rule {
      destination {
        region      = var.dr_region
        registry_id = data.aws_caller_identity.current.account_id
      }

      # 모든 레포 복제 (prefix 필터 없이 전체)
      repository_filter {
        filter      = "${var.project_name}-${var.environment}"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

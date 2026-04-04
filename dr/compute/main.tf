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
    key     = "dr/compute/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.dr_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "dr-compute"
      DR          = "true"
    }
  }
}

# 서울 리전 provider (SSM 파라미터 조회용)
provider "aws" {
  alias  = "primary"
  region = "ap-northeast-2"
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "dr-compute"
      DR          = "true"
    }
  }
}

data "aws_caller_identity" "current" {}

# 도쿄 ECR에서 서비스별 최신 이미지 조회 (업로드 시간 기준)
data "aws_ecr_image" "dr_latest" {
  for_each = local.services

  provider        = aws
  repository_name = "${var.project_name}-${var.environment}-${each.key}"
  most_recent     = true
}

# AgentCore Memory ID (서울 SSM에서 조회)
data "aws_ssm_parameter" "agentcore_memory_id" {
  provider = aws.primary
  name     = "/${var.project_name}/${var.environment}/agentcore/memory-id"
}

data "terraform_remote_state" "dr_foundation" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "dr/foundation/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Primary security remote state (ACM, Cognito 참조)
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id                 = data.terraform_remote_state.dr_foundation.outputs.vpc_id
  public_subnet_ids      = data.terraform_remote_state.dr_foundation.outputs.public_subnet_ids
  private_app_subnet_ids = data.terraform_remote_state.dr_foundation.outputs.private_app_subnet_ids
  alb_sg_id              = data.terraform_remote_state.dr_foundation.outputs.alb_security_group_id
  ecs_tasks_sg_id        = data.terraform_remote_state.dr_foundation.outputs.ecs_tasks_security_group_id

  services = {
    users    = { port = 8000, health_path = "/health", cpu = "256", memory = "512" }
    history  = { port = 8000, health_path = "/health", cpu = "256", memory = "512" }
    chatbot  = { port = 8000, health_path = "/health", cpu = "256", memory = "512" }
    analysis = { port = 8000, health_path = "/health", cpu = "256", memory = "512" }
    frontend = { port = 8080, health_path = "/", cpu = "256", memory = "512" }
  }
}

# DR 전용 서비스별 추가 환경변수는 ecs.tf의 aws_elasticache_cluster 생성 후 참조
# chatbot: REDIS_HOST, REDIS_PORT, S3_BUCKET_NAME (dr 버킷)
# users: S3_BUCKET_NAME (dr 버킷)

# 도쿄 Secrets Manager secret ARN 조회 (suffix 포함한 실제 ARN)
data "aws_secretsmanager_secret" "dr_cluster" {
  for_each = toset(["users", "history", "analysis", "chatbot"])
  name     = "${var.project_name}-${var.environment}-${each.key}-cluster-secret"
}

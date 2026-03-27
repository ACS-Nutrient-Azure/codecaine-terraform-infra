terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key     = "dr/agentcore/terraform.tfstate"
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
      Module      = "dr-agentcore"
      DR          = "true"
    }
  }
}

data "aws_caller_identity" "current" {}

# ECR 이미지는 ecr-replication으로 도쿄에 이미 복제되어 있음
locals {
  ecr_base = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.dr_region}.amazonaws.com"

  agents = {
    analysis = {
      name    = replace(lower("${var.project_name}_${var.environment}_analysis_agent"), "-", "_")
      image   = "${local.ecr_base}/${var.project_name}-${var.environment}-analysis-agent:latest"
      ssm_key = "/${var.project_name}/${var.environment}/dr/agentcore/analysis-agent/runtime-arn"
      env_vars = {
        LAMBDA_FUNCTION_NAME = lower("${var.project_name}-${var.environment}-dr-nutrient-calc")
      }
    }
    chatbot = {
      name     = replace(lower("${var.project_name}_${var.environment}_chatbot_agent"), "-", "_")
      image    = "${local.ecr_base}/${var.project_name}-${var.environment}-chatbot-agent:latest"
      ssm_key  = "/${var.project_name}/${var.environment}/dr/agentcore/chatbot-agent/runtime-arn"
      env_vars = {}
    }
    summary = {
      name     = replace(lower("${var.project_name}_${var.environment}_summary_agent"), "-", "_")
      image    = "${local.ecr_base}/${var.project_name}-${var.environment}-summary-agent:latest"
      ssm_key  = "/${var.project_name}/${var.environment}/dr/agentcore/summary-agent/runtime-arn"
      env_vars = {}
    }
  }
}

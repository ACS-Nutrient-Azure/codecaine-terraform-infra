terraform {
  required_version = ">= 1.5.0"

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
      Module      = "dms"
    }
  }
}

data "aws_caller_identity" "current" {}

# foundation 모듈에서 네트워크 정보 참조
data "terraform_remote_state" "foundation" {
  backend = "local"
  config = {
    path = "../../foundation/terraform.tfstate"
  }
}

# Secrets Manager에서 source DB 자격증명 참조 (users-cluster)
data "aws_secretsmanager_secret_version" "users_cluster" {
  secret_id = "${var.project_name}-${var.environment}-users-cluster-secret"
}

# Secrets Manager에서 target DB 자격증명 참조 (analysis-cluster)
data "aws_secretsmanager_secret_version" "analysis_cluster" {
  secret_id = "${var.project_name}-${var.environment}-analysis-cluster-secret"
}

locals {
  vpc_id                = data.terraform_remote_state.foundation.outputs.vpc_id
  private_db_subnet_ids = data.terraform_remote_state.foundation.outputs.private_db_subnet_ids
  rds_sg_id             = data.terraform_remote_state.foundation.outputs.rds_security_group_id

  users_secret    = jsondecode(data.aws_secretsmanager_secret_version.users_cluster.secret_string)
  analysis_secret = jsondecode(data.aws_secretsmanager_secret_version.analysis_cluster.secret_string)
}

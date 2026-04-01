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
    key     = "dms/terraform.tfstate"
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
      Module      = "dms"
    }
  }
}

data "aws_caller_identity" "current" {}

# ── 기존 VPC 직접 조회 (foundation tfstate 불필요) ──────────────

data "aws_vpc" "main" {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

data "aws_subnets" "private_db" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*PRIVATE-DB*"]
  }
}

data "aws_subnets" "private_app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*PRIVATE-APP*"]
  }
}

data "aws_security_group" "rds" {
  vpc_id = data.aws_vpc.main.id
  filter {
    name   = "group-name"
    values = ["${var.project_name}-${var.environment}-rds-*"]
  }
}

# ── Secrets Manager에서 DB 자격증명 조회 ───────────────────────

data "aws_secretsmanager_secret_version" "users_cluster" {
  secret_id = "${var.project_name}-${var.environment}-users-cluster-secret"
}

data "aws_secretsmanager_secret_version" "analysis_cluster" {
  secret_id = "${var.project_name}-${var.environment}-analysis-cluster-secret"
}

data "aws_secretsmanager_secret_version" "history_cluster" {
  secret_id = "${var.project_name}-${var.environment}-history-cluster-secret"
}

data "aws_secretsmanager_secret_version" "chatbot_cluster" {
  secret_id = "${var.project_name}-${var.environment}-chatbot-cluster-secret"
}

locals {
  vpc_id                 = data.aws_vpc.main.id
  private_db_subnet_ids  = data.aws_subnets.private_db.ids
  private_app_subnet_ids = data.aws_subnets.private_app.ids

  rds_users_sg_id    = data.aws_security_group.rds.id
  rds_analysis_sg_id = data.aws_security_group.rds.id
  rds_history_sg_id  = data.aws_security_group.rds.id
  rds_chatbot_sg_id  = data.aws_security_group.rds.id

  users_secret    = jsondecode(data.aws_secretsmanager_secret_version.users_cluster.secret_string)
  analysis_secret = jsondecode(data.aws_secretsmanager_secret_version.analysis_cluster.secret_string)
  history_secret  = jsondecode(data.aws_secretsmanager_secret_version.history_cluster.secret_string)
  chatbot_secret  = jsondecode(data.aws_secretsmanager_secret_version.chatbot_cluster.secret_string)
}

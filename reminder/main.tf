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
    key     = "reminder/terraform.tfstate"
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
      Module      = "reminder"
    }
  }
}

data "aws_caller_identity" "current" {}

# history DB 자격증명
data "aws_secretsmanager_secret_version" "history" {
  secret_id = "${var.project_name}-${var.environment}-history-cluster-secret"
}

# security 모듈에서 Cognito User Pool ID 참조
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# VPC (Lambda를 history DB와 같은 VPC에 배치)
data "aws_vpc" "main" {
  tags = {
    Project     = var.project_name
    Environment = var.environment
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

data "aws_security_group" "ecs_tasks" {
  vpc_id = data.aws_vpc.main.id
  filter {
    name   = "group-name"
    values = ["${var.project_name}-${var.environment}-ecs-tasks-*"]
  }
}

locals {
  history_secret = jsondecode(data.aws_secretsmanager_secret_version.history.secret_string)
}

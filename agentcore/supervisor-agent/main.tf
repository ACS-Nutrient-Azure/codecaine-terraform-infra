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
    key     = "supervisor-agent-infra/terraform.tfstate"
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
      Module      = "supervisor-agent-infra"
    }
  }
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "ecr/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "provisioner" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "agentcore-provisioner/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 하위 에이전트 runtime ARN 참조
data "terraform_remote_state" "analysis_agent" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "analysis-agent-infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "chatbot_agent" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "chatbot-agent-infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "summary_agent" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "summary-agent-infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "compute/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

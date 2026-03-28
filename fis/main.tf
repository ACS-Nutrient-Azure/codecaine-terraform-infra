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
    key     = "fis/terraform.tfstate"
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
      Module      = "fis"
    }
  }
}

data "aws_caller_identity" "current" {}

# ── Remote State ─────────────────────────────────────────────────

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "foundation/terraform.tfstate"
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

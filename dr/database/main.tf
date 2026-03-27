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
    key     = "dr/database/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

# DR 리전 (도쿄) provider
provider "aws" {
  region = var.dr_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "dr-database"
      DR          = "true"
    }
  }
}

# Primary 리전 provider (Global Cluster ID 조회용)
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

data "terraform_remote_state" "dr_foundation" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "dr/foundation/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "primary_db" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "database-rds/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "aws_caller_identity" "current" {}

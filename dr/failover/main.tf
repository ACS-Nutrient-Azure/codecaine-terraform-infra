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
    key     = "dr/failover/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

# Primary 리전 (서울) - 장애 감지 리소스
provider "aws" {
  region = var.primary_region
  default_tags {
    tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform", DR = "true" }
  }
}

# DR 리전 (도쿄) - Failover 실행 Lambda
provider "aws" {
  alias  = "dr"
  region = var.dr_region
  default_tags {
    tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform", DR = "true" }
  }
}

# Route53 (글로벌)
provider "aws" {
  alias  = "route53"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "security" {
  backend = "s3"
  config  = { bucket = "terraform-tfstate-620758375333-ap-northeast-2-an", key = "security/terraform.tfstate", region = "ap-northeast-2" }
}

data "terraform_remote_state" "compute" {
  backend = "s3"
  config  = { bucket = "terraform-tfstate-620758375333-ap-northeast-2-an", key = "compute/terraform.tfstate", region = "ap-northeast-2" }
}

data "terraform_remote_state" "dr_compute" {
  backend = "s3"
  config  = { bucket = "terraform-tfstate-620758375333-ap-northeast-2-an", key = "dr/compute/terraform.tfstate", region = "ap-northeast-2" }
}

data "terraform_remote_state" "dr_agentcore" {
  backend = "s3"
  config  = { bucket = "terraform-tfstate-620758375333-ap-northeast-2-an", key = "dr/agentcore/terraform.tfstate", region = "ap-northeast-2" }
}

data "terraform_remote_state" "primary_db" {
  backend = "s3"
  config  = { bucket = "terraform-tfstate-620758375333-ap-northeast-2-an", key = "database-rds/terraform.tfstate", region = "ap-northeast-2" }
}

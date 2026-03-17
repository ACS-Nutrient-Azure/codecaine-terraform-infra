terraform {
  required_version = ">= 1.0"
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
    }
  }
}

# Route53 is a global service but requires explicit region in Terraform
provider "aws" {
  alias  = "route53"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ACM certificate in ap-northeast-2 for ALB
provider "aws" {
  alias  = "ap_northeast_2"
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "terraform_remote_state" "foundation" {
  backend = "local"

  config = {
    path = "../foundation/terraform.tfstate"
  }
}

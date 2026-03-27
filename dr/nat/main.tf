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
    key     = "dr/nat/terraform.tfstate"
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
      Module      = "dr-nat"
      DR          = "true"
    }
  }
}

data "terraform_remote_state" "dr_foundation" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "dr/foundation/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-NAT-EIP" }
}

resource "aws_nat_gateway" "dr" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = data.terraform_remote_state.dr_foundation.outputs.public_subnet_ids[0]
  connectivity_type = "public"
  tags              = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-NAT-GW" }
  depends_on        = [aws_eip.nat]
}

resource "aws_route" "private_app_nat" {
  route_table_id         = data.terraform_remote_state.dr_foundation.outputs.private_app_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.dr.id
}

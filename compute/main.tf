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
}

data "terraform_remote_state" "common" {
  backend = "local"
  config = {
    path = "../common/terraform.tfstate"
  }
}

data "terraform_remote_state" "igw" {
  backend = "local"
  config = {
    path = "../igw/terraform.tfstate"
  }
}

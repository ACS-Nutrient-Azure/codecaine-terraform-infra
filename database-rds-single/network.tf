data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "foundation/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id                = data.terraform_remote_state.foundation.outputs.vpc_id
  private_db_subnet_ids = data.terraform_remote_state.foundation.outputs.private_db_subnet_ids
  rds_security_group_id = data.terraform_remote_state.foundation.outputs.rds_security_group_id
}

# DB Subnet Group 직접 생성
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group-single"
  subnet_ids = local.private_db_subnet_ids

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-DB-SUBNET-GROUP-SINGLE"
  }
}

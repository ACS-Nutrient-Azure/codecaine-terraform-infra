# 임시 테스트용 하드코딩 (foundation remote state 미참조)
# 실제 값: foundation terraform.tfstate에서 확인

locals {
  vpc_id                = "vpc-0e1f9143287c6e086"
  private_db_subnet_ids = ["subnet-0877ff3bdf71c3859", "subnet-062dfbf577aa64234"]
  rds_security_group_id = "sg-073c2caf2035184f3"
}

# DB Subnet Group 직접 생성 (foundation에 의존하지 않음)
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group-single"
  subnet_ids = local.private_db_subnet_ids

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-DB-SUBNET-GROUP-SINGLE"
  }
}

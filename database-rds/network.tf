# VPC Configuration for Database Cluster (독립 실행 가능)
# 기존 VPC를 사용하려면 use_existing_vpc = true로 설정

# 기존 VPC 리소스 사용 (foundation 모듈에서 생성된 VPC)
locals {
  vpc_id                = data.terraform_remote_state.foundation.outputs.vpc_id
  private_db_subnet_ids = data.terraform_remote_state.foundation.outputs.private_db_subnet_ids
  db_subnet_group_name  = data.terraform_remote_state.foundation.outputs.db_subnet_group_name
  rds_security_group_id = data.terraform_remote_state.foundation.outputs.rds_security_group_id
}

# Lambda 보안 그룹은 secrets.tf에서 정의됨 (중복 제거)

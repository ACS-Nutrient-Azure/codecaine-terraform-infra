# VPC Configuration
# foundation 모듈의 기존 VPC 사용

locals {
  # foundation 모듈에서 VPC 리소스 가져오기
  vpc_id                      = data.terraform_remote_state.foundation[0].outputs.vpc_id
  public_subnet_ids           = data.terraform_remote_state.foundation[0].outputs.public_subnet_ids
  private_app_subnet_ids      = data.terraform_remote_state.foundation[0].outputs.private_app_subnet_ids
  alb_security_group_id       = data.terraform_remote_state.foundation[0].outputs.alb_security_group_id
  ecs_tasks_security_group_id = data.terraform_remote_state.foundation[0].outputs.ecs_tasks_security_group_id
  rds_security_group_id       = data.terraform_remote_state.foundation[0].outputs.rds_security_group_id
}

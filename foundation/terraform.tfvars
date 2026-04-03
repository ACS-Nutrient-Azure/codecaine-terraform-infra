project_name = "cdci" # CodeCaine 팀 약어
environment  = "prd"
region       = "ap-northeast-2"

vpc_cidr                 = "10.0.0.0/16"
availability_zones       = ["ap-northeast-2a", "ap-northeast-2c"]
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]
dr_vpc_cidr              = "10.1.0.0/16"

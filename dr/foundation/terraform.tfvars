project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-1"

vpc_cidr                 = "10.1.0.0/16"
availability_zones       = ["ap-northeast-1a", "ap-northeast-1c"]
public_subnet_cidrs      = ["10.1.1.0/24", "10.1.2.0/24"]
private_app_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
private_db_subnet_cidrs  = ["10.1.21.0/24", "10.1.22.0/24"]

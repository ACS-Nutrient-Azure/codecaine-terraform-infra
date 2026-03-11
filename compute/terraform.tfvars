project_name = "cdci" # CodeCaine 팀 약어
environment  = "prd"
region       = "ap-northeast-2"

# ============================================
# VPC 설정 - 기존 foundation VPC 사용
# ============================================
use_existing_vpc = true

# 기존 VPC 리소스는 foundation 모듈에서 자동으로 가져옴
# data.terraform_remote_state.foundation.outputs 사용

# ECS Task 설정
task_cpu    = "256" # 0.25 vCPU
task_memory = "512" # 512 MB

container_name = "app"
container_port = 8080
image_tag      = "latest"

# 초기 태스크 수
desired_count = 1

# Health Check
health_check_path = "/health"

# 환경 변수 (예시)
environment_variables = [
  {
    name  = "NODE_ENV"
    value = "production"
  },
  {
    name  = "PORT"
    value = "8080"
  }
]

# Auto Scaling
min_capacity = 1
max_capacity = 4

cpu_target_value           = 70
memory_target_value        = 80
request_count_target_value = 1000

# HTTPS (ACM 인증서 ARN - security 모듈에서 가져오기)
certificate_arn = "arn:aws:acm:ap-northeast-2:365827924759:certificate/3a49a205-d9b8-414a-9292-4c79002d6794"

# Route53 설정
route53_zone_id = "Z009220527NRWAL7GBEUE"
domain_name     = "codecaine.yujeong91.shop"

# ECR 설정
ecr_registry        = "365827924759.dkr.ecr.ap-northeast-2.amazonaws.com"
ecr_repository_name = "codecaine-frontend" # 사용할 ECR 레포지토리 이름

# 모니터링
enable_container_insights = false # 비용 발생
log_retention_days        = 7
enable_ecs_exec           = false # 디버깅용

# Bastion Host
bastion_instance_type = "t3.micro"
bastion_key_name      = "codecaine" # codecaine.pem 키 사용
bastion_allowed_cidrs = [
  "1.2.3.4/32", # 사무실 IP
  # "5.6.7.8/32", # 집 IP
]

# ============================================
# 배포할 서비스 설정 (ECR 이미지가 있는 서비스만)
# ============================================
# 주의: ECR에 이미지가 푸시된 서비스만 enabled_services에 추가하세요
# 이미지가 없으면 Task Definition 생성 시 실패합니다
enabled_services = ["frontend", "history", "mypage", "analysis", "chatbot"] # 예: ["frontend", "history", "mypage", "analysis", "chatbot"]

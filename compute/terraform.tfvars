project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-2"

# foundation 모듈의 기존 VPC 사용
use_existing_vpc = true

# ECS Task 설정
image_tag = "latest"

# 환경 변수 (예시)
environment_variables = []

# Auto Scaling
min_capacity = 1
max_capacity = 4

cpu_target_value           = 70
memory_target_value        = 80
request_count_target_value = 1000

domain_name      = "codecaine.store"
subdomain_prefix = "www"

# 모니터링
enable_container_insights = true
log_retention_days        = 3
enable_ecs_exec           = false # 디버깅용

# Bastion Host
bastion_instance_type = "t3.micro"
bastion_key_name      = "codecaine_keypair" # tera-test.pem 키 사용
bastion_allowed_cidrs = [
  "0.0.0.0/0"
]

# ============================================
# Redis (ElastiCache) 설정
# ============================================
redis_node_type      = "cache.t3.micro"
redis_engine_version = "7.1"

# ============================================
# 배포할 서비스 설정 (ECR 이미지가 있는 서비스만)
# ============================================
# 주의: ECR에 이미지가 푸시된 서비스만 enabled_services에 추가하세요
# 이미지가 없으면 Task Definition 생성 시 실패합니다
enabled_services = ["users", "history", "chatbot", "analysis", "frontend"]

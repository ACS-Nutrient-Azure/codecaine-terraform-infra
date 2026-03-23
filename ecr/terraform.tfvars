project_name = "cdci"
environment  = "prd"
region       = "ap-northeast-2"

# MSA 서비스 목록
services = ["users", "history", "chatbot", "analysis", "frontend"]

# ECR 설정
image_tag_mutability    = "MUTABLE"
scan_on_push            = true
image_retention_count   = 10
untagged_retention_days = 7

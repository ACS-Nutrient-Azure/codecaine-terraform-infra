project_name = "cdci" # CodeCaine 팀 약어
environment  = "prd"
region       = "ap-northeast-2"

# Domain 설정
domain_name = "codecaine.yujeong91.shop"

# ============================================
# Route53 설정
# ============================================
# 기존 Route53 Hosted Zone 사용
# Zone ID: Z009220527NRWAL7GBEUE
# ACM Certificate ARN: arn:aws:acm:ap-northeast-2:365827924759:certificate/3a49a205-d9b8-414a-9292-4c79002d6794
# ============================================
create_route53_zone = false
route53_zone_id     = "Z009220527NRWAL7GBEUE"

# WAF 설정
enable_waf = true

# Shield Standard (무료)
# Shield Standard는 AWS에서 자동으로 활성화되므로 별도 설정 불필요
# Shield Advanced ($3000/month)는 사용하지 않음

# Cognito 설정
enable_cognito = true
cognito_callback_urls = [
  "http://localhost:3000/callback",
  "https://codecaine.yujeong91.shop/callback"
]
cognito_logout_urls = [
  "http://localhost:3000",
  "https://codecaine.yujeong91.shop"
]

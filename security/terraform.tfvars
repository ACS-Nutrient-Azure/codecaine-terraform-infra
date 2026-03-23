project_name = "cdci" # CodeCaine 팀 약어
environment  = "prd"
region       = "ap-northeast-2"

# Domain 설정
domain_name      = "codecaine.store" # Route53 Zone 및 ACM 루트 도메인
subdomain_prefix = "www"             # 실제 서비스 서브도메인 (www.codecaine.store)

# ============================================
# Route53 설정
# ============================================
create_route53_zone = true

# ACM 설정
# create_acm_cert = true: 신규 발급 (DNS 검증, 약 5-10분 소요)
# create_acm_cert = false: 기존 인증서 참조
create_acm_cert = true

# WAF 설정
enable_waf = true

# Shield Standard (무료)
# Shield Standard는 AWS에서 자동으로 활성화되므로 별도 설정 불필요
# Shield Advanced ($3000/month)는 사용하지 않음

# Cognito 설정
enable_cognito = true
cognito_callback_urls = [
  "http://localhost:3000/callback",
  "https://www.codecaine.store/callback"
]
cognito_logout_urls = [
  "http://localhost:3000",
  "https://www.codecaine.store"
]

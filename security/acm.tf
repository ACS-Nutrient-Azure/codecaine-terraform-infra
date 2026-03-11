# ============================================================================
# 기존 ACM 인증서 참조 (Data Source)
# ============================================================================
# 이미 AWS에 존재하는 ACM 인증서를 domain으로 검색합니다.
# ARN: arn:aws:acm:ap-northeast-2:365827924759:certificate/3a49a205-d9b8-414a-9292-4c79002d6794
# Domain: *.yujeong91.shop (와일드카드 인증서)

data "aws_acm_certificate" "existing" {
  provider = aws.ap_northeast_2

  domain      = "*.yujeong91.shop"
  statuses    = ["ISSUED"]
  most_recent = true
}

# ============================================================================
# 아래는 신규 생성 코드 (주석 처리)
# ============================================================================
# 기존 리소스가 있으므로 생성하지 않습니다.

# # ACM Certificate for ALB (Regional)
# # CloudFront를 사용할 경우 us-east-1에 생성 필요
# resource "aws_acm_certificate" "alb" {
#   provider = aws.us_east_1
# 
#   domain_name       = var.domain_name
#   validation_method = "DNS"
# 
#   subject_alternative_names = [
#     "*.${var.domain_name}"
#   ]
# 
#   lifecycle {
#     create_before_destroy = true
#   }
# 
#   tags = {
#     Name = "${upper(var.project_name)}-${upper(var.environment)}-ACM-CERT"
#   }
# }
# 
# # DNS Validation Records
# resource "aws_route53_record" "cert_validation" {
#   provider = aws.route53
# 
#   for_each = {
#     for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }
# 
#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = local.zone_id
# }
# 
# # Certificate Validation
# resource "aws_acm_certificate_validation" "alb" {
#   provider = aws.us_east_1
# 
#   certificate_arn         = aws_acm_certificate.alb.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }

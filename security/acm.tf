# ACM Certificate (ap-northeast-2 리전, ALB용)
# create_acm_cert = true: 신규 발급
# create_acm_cert = false: 기존 인증서 참조

resource "aws_acm_certificate" "main" {
  count    = var.create_acm_cert ? 1 : 0
  provider = aws.ap_northeast_2

  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ACM-CERT"
  }
}

# DNS 검증 레코드 (Route53 자동 등록)
resource "aws_route53_record" "cert_validation" {
  for_each = var.create_acm_cert ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  provider        = aws.route53
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

# 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "main" {
  count    = var.create_acm_cert ? 1 : 0
  provider = aws.ap_northeast_2

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# 기존 인증서 참조 (create_acm_cert = false 일 때)
data "aws_acm_certificate" "existing" {
  count    = var.create_acm_cert ? 0 : 1
  provider = aws.ap_northeast_2

  domain      = "*.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  acm_certificate_arn = var.create_acm_cert ? aws_acm_certificate_validation.main[0].certificate_arn : data.aws_acm_certificate.existing[0].arn
}

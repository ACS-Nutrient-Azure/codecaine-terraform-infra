# 도쿄 리전 ACM 인증서 (ALB용)
# Route53은 글로벌이므로 동일 Zone에 검증 레코드 추가
resource "aws_acm_certificate" "dr" {
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["*.${var.domain_name}"]

  lifecycle { create_before_destroy = true }

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ACM-CERT" }
}

# Route53 검증 레코드 (us-east-1 provider 필요 - Route53은 글로벌)
provider "aws" {
  alias  = "route53"
  region = "us-east-1"
}

data "aws_route53_zone" "main" {
  provider = aws.route53
  zone_id  = data.terraform_remote_state.security.outputs.route53_zone_id
}

resource "aws_route53_record" "dr_cert_validation" {
  provider = aws.route53
  for_each = {
    for dvo in aws_acm_certificate.dr.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "dr" {
  certificate_arn         = aws_acm_certificate.dr.arn
  validation_record_fqdns = [for r in aws_route53_record.dr_cert_validation : r.fqdn]
}

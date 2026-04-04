# Route53 Record for ALB
# security 모듈 remote state에서 zone_id 직접 참조

locals {
  route53_zone_id = data.terraform_remote_state.security.outputs.route53_zone_id
  # dr/failover 모듈에서 failover 레코드로 관리하므로 여기서는 생성하지 않음
  create_route53_record = false
}

data "aws_route53_zone" "main" {
  count   = local.create_route53_record ? 1 : 0
  zone_id = local.route53_zone_id
}

resource "aws_route53_record" "alb" {
  count = local.create_route53_record ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "${var.subdomain_prefix}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

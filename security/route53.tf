# Route53 Hosted Zone
# create_route53_zone = true: 신규 생성
# create_route53_zone = false: 기존 Zone 참조

resource "aws_route53_zone" "main" {
  count    = var.create_route53_zone ? 1 : 0
  provider = aws.route53

  name = var.domain_name # 루트 도메인 (yujeong91.shop)

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ROUTE53-ZONE"
  }
}

data "aws_route53_zone" "existing" {
  count    = var.create_route53_zone ? 0 : 1
  provider = aws.route53

  zone_id      = var.route53_zone_id
  private_zone = false
}

locals {
  zone_id = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

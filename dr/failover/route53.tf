# Route53 Failover Records
# Primary: 서울 ALB (PRIMARY)
# Secondary: 도쿄 ALB (SECONDARY) - Primary unhealthy 시 자동 전환

data "aws_route53_zone" "main" {
  provider = aws.route53
  zone_id  = data.terraform_remote_state.security.outputs.route53_zone_id
}

# Route53 Health Check - Primary ALB
resource "aws_route53_health_check" "primary_alb" {
  provider = aws.route53

  fqdn              = data.terraform_remote_state.compute.outputs.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health" # frontend health check
  failure_threshold = 3
  request_interval  = 30

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-PRIMARY-ALB-HC" }
}

# Primary DNS Record (서울 ALB)
resource "aws_route53_record" "primary" {
  provider = aws.route53

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain_prefix}.${var.domain_name}"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary_alb.id

  alias {
    name                   = data.terraform_remote_state.compute.outputs.alb_dns_name
    zone_id                = data.terraform_remote_state.compute.outputs.alb_zone_id
    evaluate_target_health = true
  }
}

# Secondary DNS Record (도쿄 ALB) - Primary unhealthy 시 자동 전환
resource "aws_route53_record" "secondary" {
  provider = aws.route53

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain_prefix}.${var.domain_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"

  alias {
    name                   = data.terraform_remote_state.dr_compute.outputs.dr_alb_dns_name
    zone_id                = data.terraform_remote_state.dr_compute.outputs.dr_alb_zone_id
    evaluate_target_health = true
  }
}

# DR ALB (도쿄) - 미리 생성, Failover 시 트래픽 수신
resource "aws_lb" "dr" {
  name               = lower("${var.project_name}-${var.environment}-dr-alb")
  internal           = false
  load_balancer_type = "application"
  security_groups    = [local.alb_sg_id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ALB" }
}

resource "aws_lb_target_group" "dr" {
  for_each = local.services

  name        = lower("${var.project_name}-${var.environment}-dr-${each.key}-tg")
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = each.value.health_path
    matcher             = "200"
  }

  deregistration_delay = 30
  tags                 = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-${upper(each.key)}-TG" }
}

# HTTP → HTTPS redirect
resource "aws_lb_listener" "dr_http" {
  load_balancer_arn = aws_lb.dr.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener - 도쿄 리전 ACM 인증서 사용
resource "aws_lb_listener" "dr_https" {
  load_balancer_arn = aws_lb.dr.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.dr.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dr["frontend"].arn
  }
}

resource "aws_lb_listener_rule" "dr_services" {
  for_each = {
    history  = { priority = 100, paths = ["/api/history", "/api/history/*"] }
    users    = { priority = 200, paths = ["/api/users", "/api/users/*"] }
    analysis = { priority = 300, paths = ["/api/analysis", "/api/analysis/*"] }
    chatbot  = { priority = 400, paths = ["/api/chatbot", "/api/chatbot/*"] }
  }

  listener_arn = aws_lb_listener.dr_https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dr[each.key].arn
  }

  condition {
    path_pattern { values = each.value.paths }
  }
}

resource "aws_lb_listener_rule" "dr_chatbot_ws" {
  listener_arn = aws_lb_listener.dr_https.arn
  priority     = 350

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dr["chatbot"].arn
  }

  condition {
    path_pattern { values = ["/ws/chatbot", "/ws/chatbot/*"] }
  }
}

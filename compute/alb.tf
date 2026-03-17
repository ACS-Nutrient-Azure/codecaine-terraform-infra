# Application Load Balancer
resource "aws_lb" "main" {
  name               = lower("${var.project_name}-${var.environment}-alb")
  internal           = false
  load_balancer_type = "application"
  security_groups    = [local.alb_security_group_id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection       = var.environment == "prd" ? true : false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  # ALB 로그는 s3-buckets 모듈 배포 후 활성화
  access_logs {
    bucket  = data.terraform_remote_state.s3_buckets.outputs.alb_logs_bucket_name
    enabled = true
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ALB"
  }
}

# Target Groups for each service
locals {
  all_target_groups = {
    users = {
      port        = 8000
      health_path = "/health"
    }
    history = {
      port        = 8000
      health_path = "/health"
    }
    chatbot = {
      port        = 8000
      health_path = "/health"
    }
    analysis = {
      port        = 8000
      health_path = "/health"
    }
    frontend = {
      port        = 8080
      health_path = "/"
    }
  }
  target_groups = {
    for k, v in local.all_target_groups : k => v
    if contains(var.enabled_services, k)
  }
}

resource "aws_lb_target_group" "services" {
  for_each = local.target_groups

  name        = lower("${var.project_name}-${var.environment}-${each.key}-tg")
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
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-${upper(each.key)}-TG"
    Service = each.key
  }
}

# HTTP Listener - Redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
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

# HTTPS Listener with path-based routing
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.terraform_remote_state.security.outputs.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["frontend"].arn
  }
}

# Listener Rules for path-based routing
resource "aws_lb_listener_rule" "services" {
  for_each = {
    for k, v in {
      history = {
        priority = 100
        paths    = ["/api/history", "/api/history/*"]
      }
      users = {
        priority = 200
        paths    = ["/api/mypage", "/api/mypage/*"]
      }
      analysis = {
        priority = 300
        paths    = ["/api/analysis", "/api/analysis/*"]
      }
      chatbot = {
        priority = 400
        paths    = ["/api/chatbot", "/api/chatbot/*"]
      }
    } : k => v if contains(var.enabled_services, k)
  }

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.paths
    }
  }
}

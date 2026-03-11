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

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    enabled = true
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ALB"
  }
}

# Target Groups for each service
resource "aws_lb_target_group" "services" {
  for_each = {
    history = {
      port        = 8080
      health_path = "/health"
    }
    mypage = {
      port        = 8080
      health_path = "/health"
    }
    analysis = {
      port        = 8080
      health_path = "/health"
    }
    chatbot = {
      port        = 8080
      health_path = "/health"
    }
    frontend = {
      port        = 8080
      health_path = "/health"
    }
  }

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
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["frontend"].arn
  }
}

# Listener Rules for path-based routing
resource "aws_lb_listener_rule" "services" {
  for_each = {
    history = {
      priority = 100
      paths    = ["/api/history", "/api/history/*"]
    }
    mypage = {
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

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
resource "aws_lb_target_group" "history" {
  name        = lower("${var.project_name}-${var.environment}-history-tg")
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-HISTORY-TG"
    Service = "history"
  }
}

resource "aws_lb_target_group" "mypage" {
  name        = lower("${var.project_name}-${var.environment}-mypage-tg")
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-MYPAGE-TG"
    Service = "mypage"
  }
}

resource "aws_lb_target_group" "analysis" {
  name        = lower("${var.project_name}-${var.environment}-analysis-tg")
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-ANALYSIS-TG"
    Service = "analysis"
  }
}

resource "aws_lb_target_group" "chatbot" {
  name        = lower("${var.project_name}-${var.environment}-chatbot-tg")
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-CHATBOT-TG"
    Service = "chatbot"
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = lower("${var.project_name}-${var.environment}-frontend-tg")
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-FRONTEND-TG"
    Service = "frontend"
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
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Listener Rules for path-based routing
resource "aws_lb_listener_rule" "history" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.history.arn
  }

  condition {
    path_pattern {
      values = ["/history", "/history/*"]
    }
  }
}

resource "aws_lb_listener_rule" "mypage" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mypage.arn
  }

  condition {
    path_pattern {
      values = ["/mypage", "/mypage/*"]
    }
  }
}

resource "aws_lb_listener_rule" "analysis" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.analysis.arn
  }

  condition {
    path_pattern {
      values = ["/analysis", "/analysis/*"]
    }
  }
}

resource "aws_lb_listener_rule" "chatbot" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 400

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chatbot.arn
  }

  condition {
    path_pattern {
      values = ["/chatbot", "/chatbot/*"]
    }
  }
}

# =============================================================================
# Security Groups (규칙 없이 껍데기만 정의 - 순환 참조 방지)
# 실제 ingress/egress 규칙은 아래 aws_security_group_rule 리소스로 분리
# =============================================================================

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = lower("${var.project_name}-${var.environment}-alb-")
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ALB-SG"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Tasks Security Group
resource "aws_security_group" "ecs_tasks" {
  name_prefix = lower("${var.project_name}-${var.environment}-ecs-tasks-")
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASKS-SG"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name_prefix = lower("${var.project_name}-${var.environment}-rds-")
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-RDS-SG"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Redis (ElastiCache) Security Group
resource "aws_security_group" "redis" {
  name_prefix = lower("${var.project_name}-${var.environment}-redis-")
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-REDIS-SG"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# ALB Rules
# ALB는 인터넷 facing이므로 HTTP/HTTPS inbound는 0.0.0.0/0 허용
# =============================================================================

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  description              = "Allow outbound to ECS tasks only"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.alb.id
}

# =============================================================================
# ECS Tasks Rules
# 모든 egress는 보안그룹 간 참조로만 허용 (인터넷 직접 접근 차단)
# AWS 서비스 접근은 VPC Endpoint를 통해서만 허용
# =============================================================================

resource "aws_security_group_rule" "ecs_ingress_app_from_alb" {
  type                     = "ingress"
  description              = "App port from ALB"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_ingress_frontend_from_alb" {
  type                     = "ingress"
  description              = "Frontend port from ALB"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_ingress_self" {
  type              = "ingress"
  description       = "Inter-service communication"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_egress_to_rds" {
  type                     = "egress"
  description              = "PostgreSQL to RDS"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_egress_to_redis" {
  type                     = "egress"
  description              = "Redis to ElastiCache"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.redis.id
  security_group_id        = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_egress_https_internet" {
  type              = "egress"
  description       = "HTTPS to internet via NAT Gateway (ECR, Secrets Manager, etc.)"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
}

# =============================================================================
# RDS Rules
# Bastion → RDS 접근 규칙은 compute/bastion.tf의 rds_from_bastion에서 관리
# =============================================================================

resource "aws_security_group_rule" "rds_ingress_from_ecs" {
  type                     = "ingress"
  description              = "PostgreSQL from ECS tasks"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.rds.id
}

# =============================================================================
# Redis Rules
# =============================================================================

resource "aws_security_group_rule" "redis_ingress_from_ecs" {
  type                     = "ingress"
  description              = "Redis from ECS tasks"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.redis.id
}

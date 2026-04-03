# DR ECS Cluster (도쿄) - Pilot Light
# desired_count = 0 으로 미리 생성, Failover Lambda가 2로 업데이트

resource "aws_ecs_cluster" "dr" {
  name = lower("${var.project_name}-${var.environment}-dr-cluster")

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ECS-CLUSTER" }
}

resource "aws_cloudwatch_log_group" "dr_services" {
  for_each          = local.services
  name              = lower("/ecs/${var.project_name}-${var.environment}-dr/${each.key}")
  retention_in_days = var.log_retention_days
}

# ── IAM Roles ─────────────────────────────────────────────────────

resource "aws_iam_role" "dr_ecs_task_execution" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ECS-TASK-EXECUTION-ROLE"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "dr_ecs_task_execution" {
  role       = aws_iam_role.dr_ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "dr_ecs_task_execution_secrets" {
  name = "dr-secrets-access"
  role = aws_iam_role.dr_ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.dr_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameters", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.dr_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/*"
      }
    ]
  })
}

resource "aws_iam_role" "dr_ecs_task" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ECS-TASK-ROLE"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "dr_ecs_task_runtime" {
  name = "dr-runtime-policy"
  role = aws_iam_role.dr_ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.dr_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameters", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.dr_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-chatbot-json-dr",
          "arn:aws:s3:::${var.project_name}-${var.environment}-chatbot-json-dr/*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-codef-data-dr",
          "arn:aws:s3:::${var.project_name}-${var.environment}-codef-data-dr/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock-agentcore:InvokeAgentRuntime", "bedrock-agentcore:InvokeAgentRuntimeWithResponseStream", "bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
        Resource = "*"
      }
    ]
  })
}

# ── Task Definitions (Pilot Light - 이미지는 ECR Replication으로 도쿄에 존재) ──

resource "aws_ecs_task_definition" "dr" {
  for_each = local.services

  family                   = lower("${var.project_name}-${var.environment}-dr-${each.key}")
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.dr_ecs_task_execution.arn
  task_role_arn            = aws_iam_role.dr_ecs_task.arn

  # 이미지 URI: ECR Replication으로 도쿄에 복제된 이미지 참조
  container_definitions = jsonencode([{
    name      = each.key
    image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.dr_region}.amazonaws.com/${var.project_name}-${var.environment}-${each.key}:latest"
    essential = true

    portMappings = [{ containerPort = each.value.port, protocol = "tcp" }]

    environment = concat(
      [
        { name = "PROJECT_NAME", value = var.project_name },
        { name = "ENVIRONMENT", value = var.environment },
        { name = "AWS_REGION", value = var.dr_region },
        { name = "SERVICE_NAME", value = each.key },
        { name = "ALLOWED_ORIGINS", value = "https://${var.subdomain_prefix}.${var.domain_name}" },
        { name = "COGNITO_USER_POOL_ID", value = data.terraform_remote_state.security.outputs.cognito_user_pool_id },
        { name = "COGNITO_CLIENT_ID", value = data.terraform_remote_state.security.outputs.cognito_user_pool_client_id },
        { name = "COGNITO_REGION", value = "ap-northeast-2" },
      ],
      each.key == "chatbot" ? [
        { name = "REDIS_HOST", value = aws_elasticache_cluster.dr_chatbot.cache_nodes[0].address },
        { name = "REDIS_PORT", value = tostring(aws_elasticache_cluster.dr_chatbot.port) },
        { name = "S3_BUCKET_NAME", value = "${var.project_name}-${var.environment}-chatbot-json-dr" },
        { name = "JWT_ALGORITHM", value = "RS256" },
        { name = "SKIP_AUTH", value = "false" },
      ] : [],
      each.key == "users" ? [
        { name = "S3_BUCKET_NAME", value = "${var.project_name}-${var.environment}-codef-data-dr" },
      ] : [],
    )

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.dr_services[each.key].name
        "awslogs-region"        = var.dr_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.port}${each.value.health_path} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-${upper(each.key)}-TASK-DEF" }
}

# ── ECS Services (desired_count = 0, Failover 시 Lambda가 2로 변경) ──

resource "aws_ecs_service" "dr" {
  for_each = local.services

  name            = lower("${var.project_name}-${var.environment}-dr-${each.key}-service")
  cluster         = aws_ecs_cluster.dr.id
  task_definition = aws_ecs_task_definition.dr[each.key].arn
  desired_count   = 0 # Pilot Light: 평소엔 0, Failover 시 활성화
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.private_app_subnet_ids
    security_groups  = [local.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dr[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0 # 0에서 시작하므로 0 허용

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition] # Failover Lambda가 관리
  }

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-DR-${upper(each.key)}-SERVICE"
    Service = each.key
  }

  depends_on = [aws_lb_listener.dr_http, aws_lb_listener.dr_https]
}

# ── Redis (ElastiCache) - Pilot Light ─────────────────────────────

resource "aws_elasticache_subnet_group" "dr" {
  name       = lower("${var.project_name}-${var.environment}-dr-redis-subnet")
  subnet_ids = data.terraform_remote_state.dr_foundation.outputs.private_app_subnet_ids
}

resource "aws_elasticache_cluster" "dr_chatbot" {
  cluster_id           = lower("${var.project_name}-${var.environment}-dr-chatbot")
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.dr.name
  security_group_ids   = [data.terraform_remote_state.dr_foundation.outputs.redis_security_group_id]

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-CHATBOT-REDIS" }
}

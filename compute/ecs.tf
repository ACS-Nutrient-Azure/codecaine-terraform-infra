# ECS Cluster for MSA Services
# 4개 서비스: users, history, chatbot, analysis

# Local variables for service configuration
locals {
  # 전체 서비스 정의
  all_services = {
    users = {
      name           = "users"
      container_port = 8000
      health_path    = "/health"
      cpu            = "256"
      memory         = "512"
      desired_count  = 2
    }
    history = {
      name           = "history"
      container_port = 8000
      health_path    = "/health"
      cpu            = "256"
      memory         = "512"
      desired_count  = 2
    }
    chatbot = {
      name           = "chatbot"
      container_port = 8000
      health_path    = "/health"
      cpu            = "256"
      memory         = "512"
      desired_count  = 2
    }
    analysis = {
      name           = "analysis"
      container_port = 8000
      health_path    = "/health"
      cpu            = "256"
      memory         = "512"
      desired_count  = 2
    }
    frontend = {
      name           = "frontend"
      container_port = 8080
      health_path    = "/"
      cpu            = "256"
      memory         = "512"
      desired_count  = 2
    }
  }

  # enabled_services 변수로 필터링
  services = {
    for k, v in local.all_services : k => v
    if contains(var.enabled_services, k)
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = lower("${var.project_name}-${var.environment}-cluster")

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-CLUSTER"
  }
}

# CloudWatch Log Group for each service
resource "aws_cloudwatch_log_group" "services" {
  for_each = local.services

  name              = lower("/ecs/${var.project_name}-${var.environment}/${each.value.name}")
  retention_in_days = var.log_retention_days

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-${upper(each.value.name)}-LOGS"
    Service = each.value.name
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-EXECUTION-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-EXECUTION-ROLE"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SSM Parameter Store 및 Secrets Manager 접근 권한
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-EXECUTION-SECRETS-POLICY"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.region}:*:parameter/${var.project_name}/${var.environment}/rds/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:*:secret:${var.project_name}-${var.environment}-*-secret-*"
      }
    ]
  })
}

# ECS Task Role (공통 - 모든 서비스)
resource "aws_iam_role" "ecs_task" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-ROLE"
  }
}

# ECS Task Role - 공통 런타임 권한 (Secrets Manager, SSM)
resource "aws_iam_role_policy" "ecs_task_runtime" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-RUNTIME-POLICY"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:*:secret:${var.project_name}-${var.environment}-*-secret-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.region}:*:parameter/${var.project_name}/${var.environment}/rds/*"
      }
    ]
  })
}

# ECS Task Role - chatbot 전용 S3 접근 권한 (최소 권한 원칙)
resource "aws_iam_role" "ecs_task_chatbot" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-CHATBOT-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-CHATBOT-ROLE"
  }
}

resource "aws_iam_role_policy" "ecs_task_chatbot_s3" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-CHATBOT-S3-POLICY"
  role = aws_iam_role.ecs_task_chatbot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-chatbot-json",
          "arn:aws:s3:::${var.project_name}-${var.environment}-chatbot-json/*"
        ]
      }
    ]
  })
}

# Task Definitions
resource "aws_ecs_task_definition" "services" {
  for_each = local.services

  family                   = lower("${var.project_name}-${var.environment}-${each.value.name}")
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  # chatbot은 S3 전용 Role, 나머지는 공통 Role
  task_role_arn = each.key == "chatbot" ? aws_iam_role.ecs_task_chatbot.arn : aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = "${data.terraform_remote_state.ecr.outputs.ecr_repository_urls[each.value.name]}:${data.aws_ecr_image.latest[each.key].image_tags[0]}"
      essential = true

      portMappings = [
        {
          containerPort = each.value.container_port
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [
          {
            name  = "PROJECT_NAME"
            value = var.project_name
          },
          {
            name  = "ENVIRONMENT"
            value = var.environment
          },
          {
            name  = "AWS_REGION"
            value = var.region
          },
          {
            name  = "SERVICE_NAME"
            value = each.value.name
          },
          {
            name  = "ALLOWED_ORIGINS"
            value = "https://${var.subdomain_prefix}.${var.domain_name}"
          }
        ],
        # backend 서비스에만 Cognito JWT 검증용 환경변수 주입 (frontend는 빌드타임에 CI/CD에서 처리)
        each.key != "frontend" ? [
          {
            name  = "COGNITO_USER_POOL_ID"
            value = data.terraform_remote_state.security.outputs.cognito_user_pool_id
          },
          {
            name  = "COGNITO_CLIENT_ID"
            value = data.terraform_remote_state.security.outputs.cognito_user_pool_client_id
          },
          {
            name  = "COGNITO_REGION"
            value = var.region
          }
        ] : [],
        # chatbot 전용 환경변수
        each.key == "chatbot" ? [
          {
            name  = "DYNAMODB_TABLE_NAME"
            value = "ChatbotData"
          },
          {
            name  = "DYNAMODB_ENDPOINT_URL"
            value = "http://13.125.230.157:8000"
          },
          {
            name  = "S3_BUCKET_NAME"
            value = "${var.project_name}-${var.environment}-chatbot-json"
          },
          {
            name  = "JWT_ALGORITHM"
            value = "RS256"
          },
          {
            name  = "SKIP_AUTH"
            value = "false"
          }
        ] : [],
        # history 전용 환경변수
        each.key == "history" ? [
          {
            name  = "APP_ENV"
            value = "production"
          }
        ] : [],
        # users 전용 환경변수
        each.key == "users" ? [
          {
            name  = "S3_BUCKET_NAME"
            value = "${var.project_name}-${var.environment}-codef"
          },
          {
            name  = "CODEF_CLIENT_ID"
            value = "e4fbd85c-2164-4b79-bcb3-d5171c8f59b9"
          },
          {
            name  = "CODEF_CLIENT_SECRET"
            value = "e645fad7-e06e-4d5f-a268-c41fc6b58c8b"
          },
          {
            name  = "APP_ENV"
            value = "production"
          }
        ] : [],
        var.environment_variables
      )

      # DB 정보는 history, users, analysis에만 주입
      secrets = contains(["users", "history", "analysis"], each.key) ? [
        {
          name      = "DB_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-${each.value.name}-cluster-secret:password::"
        },
        {
          name      = "DB_HOST"
          valueFrom = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/${each.value.name}-cluster/endpoint"
        },
        {
          name      = "DB_PORT"
          valueFrom = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/${each.value.name}-cluster/port"
        },
        {
          name      = "DB_NAME"
          valueFrom = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/${each.value.name}-cluster/dbname"
        },
        {
          name      = "DB_USER"
          valueFrom = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/${each.value.name}-cluster/username"
        }
      ] : []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services[each.key].name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.container_port}${each.value.health_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-${upper(each.value.name)}-TASK-DEF"
    Service = each.value.name
  }
}

# ECS Services
resource "aws_ecs_service" "services" {
  for_each = local.services

  name            = lower("${var.project_name}-${var.environment}-${each.value.name}-service")
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.private_app_subnet_ids
    security_groups  = [local.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.value.name
    container_port   = each.value.container_port
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command = var.enable_ecs_exec

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      desired_count
    ]
  }

  wait_for_steady_state = false

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-${upper(each.value.name)}-SERVICE"
    Service = each.value.name
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener.https]
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# 각 서비스별 ECR 최신 이미지 태그 동적 조회 (업로드 시간 기준)
data "aws_ecr_image" "latest" {
  for_each = local.services

  repository_name = data.terraform_remote_state.ecr.outputs.ecr_repository_names[each.key]
  most_recent     = true
}

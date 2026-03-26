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
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # AWS Secrets Manager는 시크릿 이름 뒤에 6자리 랜덤 suffix를 자동으로 붙임 (예: -a1b2c3)
        # ARN 패턴에 반드시 트레일링 와일드카드(*) 포함 필요
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-*-cluster-secret-*"
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

# ECS Task Role - 공통 런타임 권한 (Secrets Manager, SSM, S3, ECS Exec)
resource "aws_iam_role_policy" "ecs_task_runtime" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-RUNTIME-POLICY"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-*-cluster-secret-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/*"
      },
      # ECS Exec (enable_ecs_exec = true 시 필요)
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Task Role - users 전용 권한 (S3 codef-data, Textract)
resource "aws_iam_role" "ecs_task_users" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-USERS-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-USERS-ROLE"
  }
}

resource "aws_iam_role_policy" "ecs_task_users_policy" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-USERS-POLICY"
  role = aws_iam_role.ecs_task_users.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-*-cluster-secret-*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameters", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-codef-data",
          "arn:aws:s3:::${var.project_name}-${var.environment}-codef-data/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "textract:DetectDocumentText"
        Resource = "*"
      },
      {
        Sid    = "BedrockAgentCoreInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent",
          "bedrock:GetAgent",
          "bedrock:ListAgents",
          "bedrock:InvokeModel",
          "bedrock-agentcore:InvokeAgentRuntime",
          "bedrock-agentcore:InvokeAgentRuntimeWithResponseStream",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
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
      },
      # chatbot도 런타임에 Secrets Manager / SSM 접근 가능해야 함 (공통 Role과 동일)
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-*-cluster-secret-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/rds/*"
      },
      # ECS Exec (enable_ecs_exec = true 시 필요)
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Sid    = "BedrockAgentCoreInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent",
          "bedrock:GetAgent",
          "bedrock:ListAgents",
          "bedrock:InvokeModel",
          "bedrock-agentcore:InvokeAgentRuntime",
          "bedrock-agentcore:InvokeAgentRuntimeWithResponseStream",
        ]
        Resource = "*"
      }
    ]
  })
}

# Observability 공유 IAM 정책 (X-Ray + CloudWatch EMF) - ADOT sidecar용
resource "aws_iam_policy" "ecs_observability" {
  name        = "${upper(var.project_name)}-${upper(var.environment)}-ECS-OBSERVABILITY-POLICY"
  description = "X-Ray traces and CloudWatch EMF metrics for ADOT collector sidecar"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "XRayAccess"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchEMFAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_observability" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_observability.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_users_observability" {
  role       = aws_iam_role.ecs_task_users.name
  policy_arn = aws_iam_policy.ecs_observability.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_chatbot_observability" {
  role       = aws_iam_role.ecs_task_chatbot.name
  policy_arn = aws_iam_policy.ecs_observability.arn
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
  # chatbot은 S3 전용 Role, users는 Textract/codef-data Role, 나머지는 공통 Role
  task_role_arn = each.key == "chatbot" ? aws_iam_role.ecs_task_chatbot.arn : (each.key == "users" ? aws_iam_role.ecs_task_users.arn : aws_iam_role.ecs_task.arn)

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
          },
          {
            name  = "REDIS_HOST"
            value = aws_elasticache_cluster.chatbot.cache_nodes[0].address
          },
          {
            name  = "REDIS_PORT"
            value = tostring(aws_elasticache_cluster.chatbot.port)
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
            value = "${var.project_name}-${var.environment}-codef-data"
          },
          {
            name  = "CODEF_CLIENT_ID"
            value = "eaf53337-58f3-486e-9431-2a6a06e91fe5"
          },
          {
            name  = "CODEF_CLIENT_SECRET"
            value = "5fc85ddb-37f6-4f17-a8dd-fc02535e9f4b"
          },
          {
            name  = "APP_ENV"
            value = "production"
          }
        ] : [],
        # analysis 전용 환경변수
        each.key == "analysis" ? [
          {
            name  = "AGENTCORE_RUNTIME_ARN"
            value = data.terraform_remote_state.analysis_agent.outputs.agentcore_runtime_arn
          }
        ] : [],
        var.environment_variables,
        # OTEL 환경변수 (AWS Distro for OpenTelemetry)
        [
          {
            name  = "OTEL_SERVICE_NAME"
            value = "${var.project_name}-${var.environment}-${each.value.name}"
          },
          {
            name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
            value = "http://localhost:4317"
          },
          {
            name  = "OTEL_PYTHON_DISTRO"
            value = "aws_distro"
          },
          {
            name  = "OTEL_PYTHON_CONFIGURATOR"
            value = "aws_configurator"
          },
          {
            name  = "OTEL_TRACES_SAMPLER"
            value = "always_on"
          }
        ]
      )

      # DB 정보는 history, users, analysis에만 주입
      # Secrets Manager valueFrom: data source로 실제 ARN 조회 후 JSON key 추출
      secrets = contains(["users", "history", "analysis", "chatbot"], each.key) ? [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${data.aws_secretsmanager_secret.cluster[each.key].arn}:password::"
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
    },
    {
      name      = "otel-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = false

      portMappings = [
        {
          containerPort = 4317
          protocol      = "tcp"
        }
      ]

      command = ["--config=/etc/ecs/ecs-default-config.yaml"]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services[each.key].name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "otel"
        }
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

# 각 서비스별 Secrets Manager 시크릿 ARN 조회 (랜덤 suffix 포함한 실제 ARN 획득)
data "aws_secretsmanager_secret" "cluster" {
  for_each = toset(["users", "history", "analysis", "chatbot"])
  name     = "${var.project_name}-${var.environment}-${each.key}-cluster-secret"
}

# 각 서비스별 ECR 최신 이미지 태그 동적 조회 (업로드 시간 기준)
data "aws_ecr_image" "latest" {
  for_each = local.services

  repository_name = data.terraform_remote_state.ecr.outputs.ecr_repository_names[each.key]
  most_recent     = true
}

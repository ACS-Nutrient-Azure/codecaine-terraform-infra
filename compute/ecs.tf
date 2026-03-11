# Data source to get ECR repositories from foundation module
data "aws_ecr_repository" "services" {
  for_each = toset([
    "codecaine-history",
    "codecaine-mypage",
    "codecaine-analysis",
    "codecaine-chatbot",
    "codecaine-frontend"
  ])
  name = each.value
}

# Local variables for service configuration
locals {
  # All available services
  all_services = {
    history = {
      name           = "history"
      repository     = "codecaine-history"
      container_port = 8080
      health_path    = "/health"
      cpu            = "256"
      memory         = "512"
    }
    mypage = {
      name           = "mypage"
      repository     = "codecaine-mypage"
      container_port = 8080
      health_path    = "/health"
      cpu            = "256"
      memory         = "512"
    }
    analysis = {
      name           = "analysis"
      repository     = "codecaine-analysis"
      container_port = 8080
      health_path    = "/health"
      cpu            = "256"
      memory         = "512"
    }
    chatbot = {
      name           = "chatbot"
      repository     = "codecaine-chatbot"
      container_port = 8080
      health_path    = "/health"
      cpu            = "256"
      memory         = "512"
    }
    frontend = {
      name           = "frontend"
      repository     = "codecaine-frontend"
      container_port = 8080
      health_path    = "/"
      cpu            = "256"
      memory         = "512"
    }
  }

  # Filter services based on enabled_services variable
  # Only deploy services that are explicitly enabled
  services_to_deploy = {
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
  for_each = local.services_to_deploy

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

# ECS Task Role
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

# Task Definitions - Only created for enabled services
resource "aws_ecs_task_definition" "services" {
  for_each = local.services_to_deploy

  family                   = lower("${var.project_name}-${var.environment}-${each.value.name}")
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = "${data.aws_ecr_repository.services[each.value.repository].repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = each.value.container_port
          protocol      = "tcp"
        }
      ]

      environment = var.environment_variables

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

# ECS Services - Only created for enabled services
resource "aws_ecs_service" "services" {
  for_each = local.services_to_deploy

  name            = lower("${var.project_name}-${var.environment}-${each.value.name}-service")
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = var.desired_count
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

  # Prevent recreation issues when service is draining
  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      desired_count # Allow manual scaling without Terraform interference
    ]
  }

  # Add wait for steady state to ensure service is fully ready
  wait_for_steady_state = false

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-${upper(each.value.name)}-SERVICE"
    Service = each.value.name
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener.https]
}

# ECR Repositories for MSA Services
# 4개 서비스: users, history, chatbot, analysis
# AgentCore Agents: analysis-agent, chatbot-agent, supervisor-agent

resource "aws_ecr_repository" "services" {
  for_each = toset(var.services)

  name                 = lower("${var.project_name}-${var.environment}-${each.value}")
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-${upper(each.value)}-ECR"
    Service = each.value
  }
}

# Lifecycle Policy for ECR Repositories
resource "aws_ecr_lifecycle_policy" "services" {
  for_each = toset(var.services)

  repository = aws_ecr_repository.services[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.image_retention_count} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = var.image_retention_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after ${var.untagged_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_retention_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repositories for AgentCore Agents
resource "aws_ecr_repository" "agents" {
  for_each = toset(var.agents)

  name                 = lower("${var.project_name}-${var.environment}-${each.value}")
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name  = "${upper(var.project_name)}-${upper(var.environment)}-${upper(each.value)}-ECR"
    Agent = each.value
  }
}

resource "aws_ecr_lifecycle_policy" "agents" {
  for_each = toset(var.agents)

  repository = aws_ecr_repository.agents[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.image_retention_count} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest", "20"]
          countType     = "imageCountMoreThan"
          countNumber   = var.image_retention_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after ${var.untagged_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_retention_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

locals {
  ecr_name = "${var.project_name}-${var.environment}"

  # ECR Lifecycle Policy Rules
  lifecycle_rules = [
    {
      rulePriority = 1
      description  = "Keep last ${var.ecr_image_retention_count} tagged images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = [var.ecr_lifecycle_tag_prefix]
        countType     = "imageCountMoreThan"
        countNumber   = var.ecr_image_retention_count
      }
      action = {
        type = "expire"
      }
    },
    {
      rulePriority = 2
      description  = "Remove untagged images after ${var.ecr_untagged_image_retention_days} days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.ecr_untagged_image_retention_days
      }
      action = {
        type = "expire"
      }
    }
  ]

  # ECR Actions for GitHub Actions
  ecr_push_pull_actions = [
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:BatchCheckLayerAvailability",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload"
  ]
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = local.ecr_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${local.ecr_name}-ecr"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = local.lifecycle_rules
  })
}

# ECR Repository Policy for GitHub Actions
resource "aws_ecr_repository_policy" "app" {
  count      = var.github_actions_role_arn != "" ? 1 : 0
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = var.github_actions_role_arn
        }
        Action = local.ecr_push_pull_actions
      }
    ]
  })
}

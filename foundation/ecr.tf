# ECR Repositories
# CodeCaine 프로젝트의 5개 마이크로서비스용 ECR 레포지토리

locals {
  # ECR 레포지토리 목록
  ecr_repositories = [
    "codecaine-history",
    "codecaine-mypage",
    "codecaine-chatbot",
    "codecaine-analysis",
    "codecaine-frontend"
  ]

  lifecycle_rules = [
    {
      rulePriority = 1
      description  = "Keep last 10 tagged images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    },
    {
      rulePriority = 2
      description  = "Remove untagged images after 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = {
        type = "expire"
      }
    }
  ]
}

resource "aws_ecr_repository" "repositories" {
  for_each = toset(local.ecr_repositories)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${each.value}-ecr"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "repositories" {
  for_each = toset(local.ecr_repositories)

  repository = aws_ecr_repository.repositories[each.key].name

  policy = jsonencode({
    rules = local.lifecycle_rules
  })
}

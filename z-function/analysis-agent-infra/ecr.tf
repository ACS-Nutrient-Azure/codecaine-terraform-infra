resource "aws_ecr_repository" "analysis_agent" {
  name                 = "${var.project_name}-analysis-agentcore"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "analysis_agent" {
  repository = aws_ecr_repository.analysis_agent.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "최근 ${var.ecr_image_count_limit}개 이미지만 유지"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.ecr_image_count_limit
      }
      action = { type = "expire" }
    }]
  })
}

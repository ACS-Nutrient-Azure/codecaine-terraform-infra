# ── GitHub Actions OIDC Provider ────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.github_oidc_thumbprint]

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-GITHUB-OIDC"
  }
}

# ── GitHub Actions IAM Role ──────────────────────────────────────

resource "aws_iam_role" "github_actions" {
  count = var.create_github_oidc ? 1 : 0

  name = "${upper(var.project_name)}-${upper(var.environment)}-GITHUB-ACTIONS-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github[0].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-GITHUB-ACTIONS-ROLE"
  }
}

# ── ECR Push 권한 ────────────────────────────────────────────────

resource "aws_iam_role_policy" "github_actions_ecr" {
  count = var.create_github_oidc ? 1 : 0

  name = "ecr-push-policy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:${var.region}:*:repository/${var.project_name}-*"
      }
    ]
  })
}

# ── ECS 배포 권한 ────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "github_actions_ecs" {
  count = var.create_github_oidc ? 1 : 0

  name = "ecs-deploy-policy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = [
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}-${var.environment}-cluster",
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${var.project_name}-${var.environment}-cluster/*",
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:task-definition/${var.project_name}-${var.environment}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        # ECS가 task execution role / task role을 사용할 수 있도록 PassRole 허용
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-EXECUTION-ROLE",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-ROLE",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${upper(var.project_name)}-${upper(var.environment)}-ECS-TASK-CHATBOT-ROLE"
        ]
      }
    ]
  })
}

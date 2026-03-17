# IAM Role for GitHub Actions (OIDC)
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-GITHUB-OIDC"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  count = var.create_github_oidc ? 1 : 0

  name = "${upper(var.project_name)}-${upper(var.environment)}-GITHUB-ACTIONS-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-GITHUB-ACTIONS-ROLE"
  }
}

# IAM Policy for ECR Push
resource "aws_iam_role_policy" "github_actions_ecr" {
  count = var.create_github_oidc ? 1 : 0

  name = "ecr-push-policy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
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
        Resource = "arn:aws:ecr:${var.region}:*:repository/cdci-*"
      }
    ]
  })
}

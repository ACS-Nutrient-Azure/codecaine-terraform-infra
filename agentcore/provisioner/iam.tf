resource "aws_iam_role" "provisioner" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-AGENTCORE-PROVISIONER-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.provisioner.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "agentcore" {
  name = "agentcore-control"
  role = aws_iam_role.provisioner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock-agentcore:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:DescribeImages"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-AGENTCORE-RUNTIME-ROLE"
      },
      {
        Effect   = "Allow"
        Action   = "iam:UpdateAssumeRolePolicy"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-AGENTCORE-RUNTIME-ROLE"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:PutParameter", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/agentcore/*"
      }
    ]
  })
}

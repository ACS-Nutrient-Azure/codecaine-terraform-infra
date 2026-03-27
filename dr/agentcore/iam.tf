# AgentCore Runtime Role (에이전트별)
resource "aws_iam_role" "agentcore_runtime" {
  for_each = local.agents

  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-${upper(each.key)}-AGENTCORE-RUNTIME-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeRolePolicy"
      Effect    = "Allow"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:bedrock-agentcore:${var.dr_region}:${data.aws_caller_identity.current.account_id}:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "agentcore_bedrock" {
  for_each = local.agents

  name = "bedrock-invoke"
  role = aws_iam_role.agentcore_runtime[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "agentcore_ecr" {
  for_each = local.agents

  name = "ecr-pull"
  role = aws_iam_role.agentcore_runtime[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "agentcore_logs" {
  for_each = local.agents

  name = "cloudwatch-logs"
  role = aws_iam_role.agentcore_runtime[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
        Resource = "arn:aws:logs:${var.dr_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.dr_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*:log-stream:*"
      }
    ]
  })
}

# analysis-agent: nutrient-calc Lambda invoke 권한
resource "aws_iam_role_policy" "agentcore_lambda" {
  name = "invoke-lambda"
  role = aws_iam_role.agentcore_runtime["analysis"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.dr_nutrient_calc.arn
    }]
  })
}

# DR Provisioner Lambda Role
resource "aws_iam_role" "dr_provisioner" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-AGENTCORE-PROVISIONER-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dr_provisioner_basic" {
  role       = aws_iam_role.dr_provisioner.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dr_provisioner_agentcore" {
  name = "agentcore-control"
  role = aws_iam_role.dr_provisioner.id

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
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-DR-*-AGENTCORE-RUNTIME-ROLE"
      },
      {
        Effect   = "Allow"
        Action   = "iam:UpdateAssumeRolePolicy"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-DR-*-AGENTCORE-RUNTIME-ROLE"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:PutParameter", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.dr_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/dr/agentcore/*"
      }
    ]
  })
}

# nutrient-calc Lambda Role
resource "aws_iam_role" "dr_lambda_exec" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ANALYSIS-LAMBDA-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dr_lambda_basic" {
  role       = aws_iam_role.dr_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

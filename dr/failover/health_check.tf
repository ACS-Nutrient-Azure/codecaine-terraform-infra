# AgentCore Health Check Lambda + EventBridge Scheduled Rule

data "archive_file" "agentcore_health" {
  type        = "zip"
  source_file = "${path.module}/agentcore_health_lambda.py"
  output_path = "${path.module}/files/agentcore_health.zip"
}

resource "aws_iam_role" "agentcore_health_lambda" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-AGENTCORE-HEALTH-ROLE"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "agentcore_health_basic" {
  role       = aws_iam_role.agentcore_health_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "agentcore_health_policy" {
  name = "agentcore-health-policy"
  role = aws_iam_role.agentcore_health_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.primary_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/agentcore/*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock-agentcore:GetAgentRuntime", "bedrock-agentcore:ListAgentRuntimes"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "agentcore_health" {
  function_name    = lower("${var.project_name}-${var.environment}-dr-agentcore-health")
  runtime          = "python3.12"
  handler          = "agentcore_health_lambda.lambda_handler"
  role             = aws_iam_role.agentcore_health_lambda.arn
  timeout          = 30
  filename         = data.archive_file.agentcore_health.output_path
  source_code_hash = data.archive_file.agentcore_health.output_base64sha256

  environment {
    variables = {
      PRIMARY_REGION = var.primary_region
      PROJECT_NAME   = var.project_name
      ENVIRONMENT    = var.environment
    }
  }
}

# EventBridge: 1분마다 Health Check 실행
resource "aws_cloudwatch_event_rule" "agentcore_health_schedule" {
  name                = "${var.project_name}-${var.environment}-dr-agentcore-health-schedule"
  description         = "AgentCore Runtime 헬스체크 (1분마다)"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "agentcore_health" {
  rule      = aws_cloudwatch_event_rule.agentcore_health_schedule.name
  target_id = "agentcore-health-lambda"
  arn       = aws_lambda_function.agentcore_health.arn
}

resource "aws_lambda_permission" "agentcore_health_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.agentcore_health.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.agentcore_health_schedule.arn
}

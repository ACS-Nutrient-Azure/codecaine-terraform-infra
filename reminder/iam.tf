# Lambda 실행 Role
resource "aws_iam_role" "reminder_lambda" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-PURCHASE-REMINDER-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "reminder_basic" {
  role       = aws_iam_role.reminder_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC 내 Lambda 실행 권한
resource "aws_iam_role_policy_attachment" "reminder_vpc" {
  role       = aws_iam_role.reminder_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "reminder_policy" {
  name = "reminder-policy"
  role = aws_iam_role.reminder_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Cognito 이메일 조회
      {
        Effect   = "Allow"
        Action   = ["cognito-idp:AdminGetUser"]
        Resource = "arn:aws:cognito-idp:${var.region}:${data.aws_caller_identity.current.account_id}:userpool/*"
      },
      # SES 이메일 발송
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      },
      # Secrets Manager (DB 자격증명)
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = data.aws_secretsmanager_secret_version.history.arn
      }
    ]
  })
}

# EventBridge Scheduler Role
resource "aws_iam_role" "scheduler" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-REMINDER-SCHEDULER-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_policy" {
  name = "invoke-lambda"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.reminder.arn
    }]
  })
}

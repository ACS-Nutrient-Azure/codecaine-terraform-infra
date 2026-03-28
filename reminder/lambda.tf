data "archive_file" "reminder" {
  type        = "zip"
  source_dir  = "${path.module}/package"
  output_path = "${path.module}/files/reminder.zip"
}

resource "aws_lambda_function" "reminder" {
  function_name    = lower("${var.project_name}-${var.environment}-purchase-reminder")
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.reminder_lambda.arn
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.reminder.output_path
  source_code_hash = data.archive_file.reminder.output_base64sha256

  vpc_config {
    subnet_ids         = data.aws_subnets.private_app.ids
    security_group_ids = [data.aws_security_group.ecs_tasks.id]
  }

  environment {
    variables = {
      DB_HOST              = local.history_secret["host"]
      DB_PORT              = tostring(local.history_secret["port"])
      DB_NAME              = local.history_secret["dbname"]
      DB_USER              = local.history_secret["username"]
      DB_PASSWORD          = local.history_secret["password"]
      COGNITO_USER_POOL_ID = data.terraform_remote_state.security.outputs.cognito_user_pool_id
      SES_FROM_EMAIL       = var.ses_from_email
      DAYS_THRESHOLD       = tostring(var.reminder_days_threshold)
    }
  }

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-PURCHASE-REMINDER" }
}

resource "aws_cloudwatch_log_group" "reminder" {
  name              = "/aws/lambda/${aws_lambda_function.reminder.function_name}"
  retention_in_days = 7
}

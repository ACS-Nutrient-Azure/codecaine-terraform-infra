data "archive_file" "provisioner" {
  type        = "zip"
  source_file = "${path.module}/files/handler.py"
  output_path = "${path.module}/files/provisioner.zip"
}

resource "aws_lambda_function" "provisioner" {
  function_name = lower("${var.project_name}-${var.environment}-agentcore-provisioner")
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  role          = aws_iam_role.provisioner.arn
  timeout       = 90
  memory_size   = 256

  filename         = data.archive_file.provisioner.output_path
  source_code_hash = data.archive_file.provisioner.output_base64sha256
}

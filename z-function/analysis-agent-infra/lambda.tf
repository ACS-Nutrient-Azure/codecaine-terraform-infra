data "archive_file" "nutrient_calc" {
  type        = "zip"
  source_file = "${path.module}/files/handler.py"
  output_path = "${path.module}/files/nutrient_calc.zip"
}

resource "aws_lambda_function" "nutrient_calc" {
  function_name = "${var.project_name}-nutrient-calc"
  runtime       = var.lambda_runtime
  handler       = "handler.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.nutrient_calc.output_path
  source_code_hash = data.archive_file.nutrient_calc.output_base64sha256

  tags = local.tags
}

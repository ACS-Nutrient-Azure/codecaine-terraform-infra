# DR Provisioner Lambda - Primary와 동일한 handler.py 사용
data "archive_file" "dr_provisioner" {
  type        = "zip"
  source_file = "${path.module}/../../agentcore/provisioner/files/handler.py"
  output_path = "${path.module}/files/dr_provisioner.zip"
}

resource "aws_lambda_function" "dr_provisioner" {
  function_name    = lower("${var.project_name}-${var.environment}-dr-agentcore-provisioner")
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.dr_provisioner.arn
  timeout          = 90
  memory_size      = 256
  filename         = data.archive_file.dr_provisioner.output_path
  source_code_hash = data.archive_file.dr_provisioner.output_base64sha256
}

# DR nutrient-calc Lambda - Primary와 동일한 handler.py 사용
data "archive_file" "dr_nutrient_calc" {
  type        = "zip"
  source_file = "${path.module}/../../agentcore/analysis-agent/files/handler.py"
  output_path = "${path.module}/files/dr_nutrient_calc.zip"
}

resource "aws_lambda_function" "dr_nutrient_calc" {
  function_name    = lower("${var.project_name}-${var.environment}-dr-nutrient-calc")
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.dr_lambda_exec.arn
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.dr_nutrient_calc.output_path
  source_code_hash = data.archive_file.dr_nutrient_calc.output_base64sha256
}

# SSM 파라미터 - Failover 전까지 pending 상태로 미리 생성
resource "aws_ssm_parameter" "dr_agentcore_runtime_arn" {
  for_each = local.agents

  name  = each.value.ssm_key
  type  = "String"
  value = "pending"

  lifecycle {
    ignore_changes = [value] # Failover Lambda가 실제 ARN으로 업데이트
  }
}

# Failover Lambda가 참조할 Runtime Role ARN → SSM에 저장
resource "aws_ssm_parameter" "dr_agentcore_role_arn" {
  for_each = local.agents

  name  = "/${var.project_name}/${var.environment}/dr/agentcore/${each.key}-role-arn"
  type  = "String"
  value = aws_iam_role.agentcore_runtime[each.key].arn
}

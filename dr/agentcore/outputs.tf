output "dr_provisioner_lambda_name" {
  value = aws_lambda_function.dr_provisioner.function_name
}

output "dr_provisioner_lambda_arn" {
  value = aws_lambda_function.dr_provisioner.arn
}

output "dr_agentcore_runtime_role_arns" {
  value = { for k, v in aws_iam_role.agentcore_runtime : k => v.arn }
}

output "dr_nutrient_calc_lambda_arn" {
  value = aws_lambda_function.dr_nutrient_calc.arn
}

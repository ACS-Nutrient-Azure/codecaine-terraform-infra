locals {
  agent_name  = replace(lower("${var.project_name}_${var.environment}_summary_agent"), "-", "_")
  image_uri   = data.terraform_remote_state.ecr.outputs.agent_repository_urls["summary-agent"]
  ssm_arn_key = "/${var.project_name}/${var.environment}/agentcore/summary-agent/runtime-arn"
}

resource "aws_lambda_invocation" "agentcore_runtime" {
  function_name = data.terraform_remote_state.provisioner.outputs.lambda_function_name

  input = jsonencode({
    region       = var.region
    agent_name   = local.agent_name
    image_uri    = local.image_uri
    role_arn     = aws_iam_role.agentcore_runtime.arn
    ssm_key      = local.ssm_arn_key
    network_mode = var.agentcore_network_mode
    network_mode_config = var.agentcore_network_mode == "VPC" ? {
      subnet_ids         = data.terraform_remote_state.compute.outputs.private_app_subnet_ids
      security_group_ids = [data.terraform_remote_state.compute.outputs.ecs_tasks_security_group_id]
    } : null
    idle_timeout = var.agentcore_idle_timeout
    max_lifetime = var.agentcore_max_lifetime
    environment_variables = {
      AWS_REGION       = var.region
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  })

  triggers = {
    agent_name        = local.agent_name
    role_arn          = aws_iam_role.agentcore_runtime.arn
    trust_policy_hash = sha256(aws_iam_role.agentcore_runtime.assume_role_policy)
  }

  depends_on = [aws_iam_role.agentcore_runtime]
}

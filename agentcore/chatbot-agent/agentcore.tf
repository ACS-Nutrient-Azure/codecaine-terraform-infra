locals {
  agent_name  = replace(lower("${var.project_name}_${var.environment}_chatbot_agent"), "-", "_")
  image_uri   = data.terraform_remote_state.ecr.outputs.agent_repository_urls["chatbot-agent"]
  ssm_arn_key = "/${var.project_name}/${var.environment}/agentcore/chatbot-agent/runtime-arn"

  # Secrets Manager에서 chatbot DB 자격증명 조회
  chatbot_secret = jsondecode(data.aws_secretsmanager_secret_version.chatbot_cluster.secret_string)
}

# chatbot-cluster DB 자격증명 (Secrets Manager)
data "aws_secretsmanager_secret_version" "chatbot_cluster" {
  secret_id = "${var.project_name}-${var.environment}-chatbot-cluster-secret"
}

# DB endpoint/port (SSM Parameter Store)
data "aws_ssm_parameter" "db_endpoint" {
  name = "/${var.project_name}/${var.environment}/rds/chatbot-cluster/endpoint"
}

data "aws_ssm_parameter" "db_port" {
  name = "/${var.project_name}/${var.environment}/rds/chatbot-cluster/port"
}

data "aws_ssm_parameter" "db_name" {
  name = "/${var.project_name}/${var.environment}/rds/chatbot-cluster/dbname"
}

# AgentCore Memory ID (SSM - agentcore/memory 모듈에서 저장)
data "aws_ssm_parameter" "memory_id" {
  name = "/${var.project_name}/${var.environment}/agentcore/memory-id"
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
      KB_LOCAL_PATH    = var.kb_local_path
      KB_TOP_K         = tostring(var.kb_top_k)
      DB_HOST          = data.aws_ssm_parameter.db_endpoint.value
      DB_PORT          = data.aws_ssm_parameter.db_port.value
      DB_NAME          = data.aws_ssm_parameter.db_name.value
      DB_USER          = local.chatbot_secret["username"]
      DB_PASSWORD      = local.chatbot_secret["password"]
      USE_MEMORY       = tostring(var.use_memory)
      MEMORY_ID        = data.aws_ssm_parameter.memory_id.value
    }
  })

  triggers = {
    agent_name        = local.agent_name
    role_arn          = aws_iam_role.agentcore_runtime.arn
    trust_policy_hash = sha256(aws_iam_role.agentcore_runtime.assume_role_policy)
  }

  depends_on = [aws_iam_role.agentcore_runtime]
}

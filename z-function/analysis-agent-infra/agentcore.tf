resource "aws_bedrockagentcore_runtime" "analysis_agent" {
  agent_runtime_name = "${var.project_name}_agent"

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.analysis_agent.repository_url}:latest"
    }
  }

  network_configuration {
    network_mode = var.agentcore_network_mode
  }

  role_arn = aws_iam_role.agentcore_runtime.arn

  lifecycle_configuration {
    idle_runtime_session_timeout = var.agentcore_idle_timeout
    max_lifetime                 = var.agentcore_max_lifetime
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [agent_runtime_artifact]
  }
}

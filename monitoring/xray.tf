# ============================================================
# X-Ray Groups (서비스별 트레이스 필터링)
# OTEL_SERVICE_NAME = cdci-prd-{service} 형식으로 매핑
# ============================================================
locals {
  xray_services = ["analysis", "chatbot", "frontend", "history", "users"]
  xray_agents   = ["analysis-agent", "chatbot-agent", "supervisor-agent", "summary-agent", "question-agent"]
}

resource "aws_xray_group" "services" {
  for_each = toset(local.xray_services)

  group_name        = "cdci-prd-${each.value}-service"
  filter_expression = "service(id(name: \"cdci-prd-${each.value}\"))"

  insights_configuration {
    insights_enabled      = false
    notifications_enabled = false
  }

  tags = {
    Name    = "cdci-prd-${each.value}-service"
    Service = each.value
  }
}

# AgentCore 에이전트별 X-Ray 그룹 (aws-xray-sdk 직접 전송)
resource "aws_xray_group" "agents" {
  for_each = toset(local.xray_agents)

  group_name        = "cdci-prd-${each.value}"
  filter_expression = "service(id(name: \"cdci-prd-${each.value}\"))"

  insights_configuration {
    insights_enabled      = false
    notifications_enabled = false
  }

  tags = {
    Name    = "cdci-prd-${each.value}"
    Service = each.value
    Type    = "agentcore"
  }
}

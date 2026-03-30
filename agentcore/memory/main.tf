terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key     = "agentcore-memory/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "agentcore-memory"
    }
  }
}

provider "awscc" {
  region = var.region
}

# ── AgentCore Memory ──────────────────────────────────────────────
# CLI 동등:
#   aws bedrock-agentcore create-memory
#     --memory-name "chatbot-session-memory"
#     --description "채팅 세션 단기 기억"
#     --retention-days 7

resource "awscc_bedrockagentcore_memory" "chatbot_session" {
  name                  = var.memory_name
  description           = var.memory_description
  event_expiry_duration = var.retention_days
}

# memory_id를 SSM에 저장 (다른 모듈에서 참조용)
resource "aws_ssm_parameter" "memory_id" {
  name  = "/${var.project_name}/${var.environment}/agentcore/memory-id"
  type  = "String"
  value = awscc_bedrockagentcore_memory.chatbot_session.memory_id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-AGENTCORE-MEMORY-ID"
  }
}

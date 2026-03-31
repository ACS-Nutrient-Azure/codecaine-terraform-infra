variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev / stg / prd)"
  type        = string
}

variable "github_org" {
  description = "GitHub 조직명"
  type        = string
}

variable "github_repo" {
  description = "GitHub 레포명"
  type        = string
}

variable "agentcore_idle_timeout" {
  description = "AgentCore Runtime 유휴 세션 타임아웃 (초)"
  type        = number
  default     = 300
}

variable "agentcore_max_lifetime" {
  description = "AgentCore Runtime 최대 세션 유지 시간 (초)"
  type        = number
  default     = 1800
}

variable "agentcore_network_mode" {
  description = "AgentCore Runtime 네트워크 모드 (PUBLIC / VPC)"
  type        = string
  default     = "PUBLIC"
}

# ECR 레포는 ecr 모듈에서 관리 (ecr/ecr.tf)

variable "bedrock_model_id" {
  description = "Bedrock model ID for LLM"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20240620-v1:0"
}

variable "kb_local_path" {
  description = "Knowledge Base 로컬 경로"
  type        = string
  default     = "/app"
}

variable "kb_top_k" {
  description = "Knowledge Base 검색 결과 수"
  type        = number
  default     = 3
}

variable "use_memory" {
  description = "AgentCore Memory 사용 여부"
  type        = bool
  default     = true
}

# ── AWS ──────────────────────────────────────────────────────────

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# ── 프로젝트 ─────────────────────────────────────────────────────

variable "project_name" {
  description = "프로젝트명 (리소스 이름 prefix로 사용)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev / stg / prd)"
  type        = string
}

# ── GitHub ───────────────────────────────────────────────────────

variable "github_org" {
  description = "GitHub 조직명"
  type        = string
}

variable "github_repo" {
  description = "GitHub 레포명"
  type        = string
}

# ── Lambda ───────────────────────────────────────────────────────

variable "lambda_timeout" {
  description = "Lambda 타임아웃 (초)"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda 메모리 (MB)"
  type        = number
  default     = 256
}

variable "lambda_runtime" {
  description = "Lambda 런타임"
  type        = string
  default     = "python3.12"
}

# ── AgentCore Runtime ─────────────────────────────────────────────

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

# ── ECR ──────────────────────────────────────────────────────────
# ECR 레포는 ecr 모듈에서 관리 (ecr/ecr.tf)

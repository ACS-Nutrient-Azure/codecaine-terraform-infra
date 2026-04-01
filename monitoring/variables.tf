variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (prd, stg, dev)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "grafana_admin_groups" {
  description = "SSO group IDs to assign as Grafana admins"
  type        = list(string)
  default     = []
}

variable "grafana_api_key" {
  description = "Grafana service account token"
  type        = string
  sensitive   = true
}

# ============================================================
# CloudWatch Alarms 변수
# ============================================================

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}

variable "alarm_cpu_threshold" {
  description = "ECS CPU utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "alarm_memory_threshold" {
  description = "ECS memory utilization alarm threshold (%)"
  type        = number
  default     = 85
}

# ============================================================
# Phase 2 변수
# ============================================================

variable "bedrock_model_id" {
  description = "Bedrock model ID for alarm enrichment (Claude Haiku)"
  type        = string
  default     = "apac.anthropic.claude-3-haiku-20240307-v1:0"
}

variable "ses_sender_email" {
  description = "SES verified sender email for enriched alarm notifications"
  type        = string
  sensitive   = true
}

variable "alarm_recipient_email" {
  description = "Recipient email address for enriched alarm notifications"
  type        = string
  sensitive   = true
}

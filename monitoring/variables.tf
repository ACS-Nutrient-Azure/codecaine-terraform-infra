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

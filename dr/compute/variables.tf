variable "dr_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project_name" { type = string }
variable "environment" { type = string }

variable "domain_name" {
  type    = string
  default = "codecaine.store"
}

variable "subdomain_prefix" {
  type    = string
  default = "www"
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "codef_client_id" {
  type    = string
  default = "eaf53337-58f3-486e-9431-2a6a06e91fe5"
}

variable "codef_client_secret" {
  type    = string
  default = "5fc85ddb-37f6-4f17-a8dd-fc02535e9f4b"
}

variable "dr_analysis_agent_arn" {
  type        = string
  default     = ""
  description = "DR AgentCore analysis agent runtime ARN (Failover 후 SSM에서 수동 업데이트)"
}

variable "dr_supervisor_agent_arn" {
  type        = string
  default     = ""
  description = "DR AgentCore supervisor agent runtime ARN (Failover 후 SSM에서 수동 업데이트)"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name (cdci)"
  type        = string
}

variable "environment" {
  description = "Environment (prd/stg/dev)"
  type        = string
}

variable "services" {
  description = "List of microservices"
  type        = list(string)
  default     = ["users", "history", "chatbot", "analysis", "frontend"]
}

variable "agents" {
  description = "List of AgentCore agents"
  type        = list(string)
  default     = ["analysis-agent", "chatbot-agent", "supervisor-agent"]
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "image_retention_count" {
  description = "Number of images to retain"
  type        = number
  default     = 10
}

variable "untagged_retention_days" {
  description = "Days to retain untagged images"
  type        = number
  default     = 7
}

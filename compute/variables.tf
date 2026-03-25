variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev/stg/prd)"
  type        = string
}

# ECS Configuration
variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Auto Scaling
variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "Target memory utilization percentage"
  type        = number
  default     = 80
}

variable "request_count_target_value" {
  description = "Target request count per target"
  type        = number
  default     = 1000
}

# ALB Configuration
# certificate_arn은 security remote state에서 자동 참조

# Monitoring
variable "enable_container_insights" {
  description = "Enable ECS Container Insights"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

# Bastion Host Variables
variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_name" {
  description = "EC2 key pair name for bastion host SSH access (e.g., codecaine_keypair)"
  type        = string
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion"
  type        = list(string)
  default     = []
}

# Network Configuration
variable "use_existing_vpc" {
  description = "Use existing VPC resources from foundation module"
  type        = bool
  default     = true
}

# Route53 Configuration
# route53_zone_id는 security remote state에서 자동 참조

variable "domain_name" {
  description = "Root domain name (e.g., codecaine.store)"
  type        = string
  default     = ""
}

variable "subdomain_prefix" {
  description = "Subdomain prefix for the service (e.g., codecaine → www.codecaine.store)"
  type        = string
  default     = "www"
}

# Redis Configuration
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "ElastiCache Redis engine version"
  type        = string
  default     = "7.1"
}

# Service Deployment Configuration
variable "enabled_services" {
  description = "List of services to deploy (only services with ECR images should be enabled)"
  type        = list(string)
  default     = ["users", "history", "chatbot", "analysis", "frontend"]
  validation {
    condition = alltrue([
      for service in var.enabled_services :
      contains(["users", "history", "chatbot", "analysis", "frontend"], service)
    ])
    error_message = "Enabled services must be one of: users, history, chatbot, analysis, frontend"
  }
}



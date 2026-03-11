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
variable "task_cpu" {
  description = "Task CPU units (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Task memory in MB (512, 1024, 2048, 4096, 8192)"
  type        = string
  default     = "512"
}

variable "container_name" {
  description = "Container name"
  type        = string
  default     = "app"
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
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
variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

# Monitoring
variable "enable_container_insights" {
  description = "Enable ECS Container Insights"
  type        = bool
  default     = false
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
  description = "EC2 key pair name for bastion host SSH access (e.g., codecaine)"
  type        = string
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion"
  type        = list(string)
  default     = []
}

# Network Configuration (독립 실행 모드)
variable "use_existing_vpc" {
  description = "Use existing VPC resources (false = create new VPC)"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "VPC CIDR block (독립 모드)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones (독립 모드)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks (독립 모드)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private application subnet CIDR blocks (독립 모드)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets (독립 모드)"
  type        = bool
  default     = true
}

# Existing VPC Configuration (기존 VPC 사용 시)
variable "existing_vpc_id" {
  description = "Existing VPC ID (use_existing_vpc = true)"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "Existing public subnet IDs (use_existing_vpc = true)"
  type        = list(string)
  default     = []
}

variable "existing_private_app_subnet_ids" {
  description = "Existing private app subnet IDs (use_existing_vpc = true)"
  type        = list(string)
  default     = []
}

variable "existing_alb_security_group_id" {
  description = "Existing ALB security group ID (use_existing_vpc = true)"
  type        = string
  default     = ""
}

variable "existing_ecs_tasks_security_group_id" {
  description = "Existing ECS tasks security group ID (use_existing_vpc = true)"
  type        = string
  default     = ""
}

# Route53 Configuration
variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for ALB (e.g., codecaine.yujeong91.shop)"
  type        = string
  default     = ""
}

# ECR Configuration
variable "ecr_registry" {
  description = "ECR registry URL"
  type        = string
  default     = "365827924759.dkr.ecr.ap-northeast-2.amazonaws.com"
}

variable "ecr_repository_name" {
  description = "ECR repository name to use for ECS task"
  type        = string
  default     = "codecaine-frontend"
}

# Service Deployment Configuration
variable "enabled_services" {
  description = "List of services to deploy (only services with ECR images should be enabled)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for service in var.enabled_services :
      contains(["history", "mypage", "analysis", "chatbot", "frontend"], service)
    ])
    error_message = "Enabled services must be one of: history, mypage, analysis, chatbot, frontend"
  }
}

# Deprecated ECR variables (kept for backward compatibility)
variable "use_existing_ecr" {
  description = "Use existing ECR repository (false = create new ECR)"
  type        = bool
  default     = false
}

variable "existing_ecr_repository_url" {
  description = "Existing ECR repository URL (use_existing_ecr = true)"
  type        = string
  default     = ""
}

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

variable "ecs_task_execution_role_arn" {
  description = "ECS Task Execution Role ARN for CODEF bucket policy"
  type        = string
  default     = ""
}

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

variable "create_github_oidc" {
  description = "Create GitHub OIDC provider and role"
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repository (format: owner/repo)"
  type        = string
  default     = ""
}

variable "github_actions_role_arn" {
  description = "Existing GitHub Actions IAM role ARN (if not creating new)"
  type        = string
  default     = ""
}

variable "ecr_image_retention_count" {
  description = "Number of tagged images to retain"
  type        = number
  default     = 10
}

variable "ecr_untagged_image_retention_days" {
  description = "Number of days to retain untagged images"
  type        = number
  default     = 7
}

variable "ecr_lifecycle_tag_prefix" {
  description = "Tag prefix for lifecycle policy"
  type        = string
  default     = "v"
}

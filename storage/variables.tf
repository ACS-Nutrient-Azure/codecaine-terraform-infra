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

variable "github_org" {
  description = "GitHub 조직명"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub 레포명"
  type        = string
  default     = ""
}

variable "github_oidc_thumbprint" {
  description = "GitHub OIDC Provider thumbprint"
  type        = string
  # 변경되는 경우 https://github.blog/changelog 에서 확인
  default = "6938fd4d98bab03faadb97b34396831e3780aea1"
}

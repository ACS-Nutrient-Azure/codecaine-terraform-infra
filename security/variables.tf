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

variable "domain_name" {
  description = "Root domain name for Route53 Zone and ACM certificate (e.g., yujeong91.shop)"
  type        = string
}

variable "subdomain_prefix" {
  description = "Subdomain prefix for the service (e.g., codecaine → codecaine.yujeong91.shop)"
  type        = string
  default     = "codecaine"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID (if exists)"
  type        = string
  default     = ""
}

variable "create_route53_zone" {
  description = "Create new Route53 hosted zone"
  type        = bool
  default     = false
}

variable "create_acm_cert" {
  description = "Create new ACM certificate (false = use existing)"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable WAF"
  type        = bool
  default     = true
}

# Shield Advanced 변수 제거됨
# Shield Standard는 AWS에서 자동으로 활성화되므로 별도 설정 불필요

variable "enable_cognito" {
  description = "Enable Cognito User Pool"
  type        = bool
  default     = true
}

variable "cognito_callback_urls" {
  description = "Cognito callback URLs"
  type        = list(string)
  default     = ["http://localhost:3000/callback"]
}

variable "cognito_logout_urls" {
  description = "Cognito logout URLs"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

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
  description = "Environment"
  type        = string
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways (1 or 2)"
  type        = number
  default     = 1
}

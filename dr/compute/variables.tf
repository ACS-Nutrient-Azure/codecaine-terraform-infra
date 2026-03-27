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

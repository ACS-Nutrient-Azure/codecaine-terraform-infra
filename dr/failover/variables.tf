variable "primary_region" {
  type    = string
  default = "ap-northeast-2"
}

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

variable "alarm_sns_email" {
  description = "DR 알림 수신 이메일"
  type        = string
}

# ALB UnhealthyHost 임계값 - 전체 서비스(5개) 중 3개 이상 unhealthy 시 트리거
variable "unhealthy_host_threshold" {
  type    = number
  default = 3
}

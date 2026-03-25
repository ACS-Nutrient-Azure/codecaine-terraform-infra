variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev / stg / prd)"
  type        = string
}

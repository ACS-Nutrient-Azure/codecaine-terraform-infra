variable "primary_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "dr_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aurora_postgres_version" {
  type    = string
  default = "15.8"
}

# Aurora Serverless v2는 Global Database Secondary에서 min_capacity 0.5 지원
variable "dr_serverless_min_capacity" {
  type    = number
  default = 0.5
}

variable "dr_serverless_max_capacity" {
  type    = number
  default = 2
}

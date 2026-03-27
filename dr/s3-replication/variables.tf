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

variable "dr_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project_name" { type = string }
variable "environment" { type = string }

variable "agentcore_network_mode" {
  type    = string
  default = "PUBLIC"
}

variable "agentcore_idle_timeout" {
  type    = number
  default = 300
}

variable "agentcore_max_lifetime" {
  type    = number
  default = 1800
}

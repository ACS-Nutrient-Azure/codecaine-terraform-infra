variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "memory_name" {
  type    = string
  default = "chatbot-session-memory"
}

variable "memory_description" {
  type    = string
  default = "채팅 세션 단기 기억"
}

variable "retention_days" {
  type    = number
  default = 7
}

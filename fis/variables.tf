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

variable "stop_condition_alarm_arn" {
  description = "CloudWatch Alarm ARN used as FIS stop condition (experiment halts if alarm fires)"
  type        = string
}

variable "notification_email" {
  description = "Email for FIS experiment result notifications"
  type        = string
  default     = ""
}

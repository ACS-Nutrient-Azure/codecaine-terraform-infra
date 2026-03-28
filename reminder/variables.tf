variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" { type = string }
variable "environment" { type = string }

variable "reminder_days_threshold" {
  description = "remain_day 이하일 때 알림 발송"
  type        = number
  default     = 1
}

variable "schedule_expression" {
  description = "EventBridge Scheduler cron (KST 09:00 = UTC 00:00)"
  type        = string
  default     = "cron(0 0 * * ? *)"
}

variable "ses_from_email" {
  description = "SES 발신 이메일 (SES에서 검증된 이메일)"
  type        = string
}

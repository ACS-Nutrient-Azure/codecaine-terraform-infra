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
  description = "CloudWatch Alarm ARN used as FIS stop condition (experiment halts if alarm fires). Leave empty to auto-create a dummy alarm."
  type        = string
  default     = ""
}

variable "notification_email" {
  description = "Email for FIS experiment result notifications"
  type        = string
  default     = ""
}

# ── ECS 태스크 ARN (실험 전 현재 ARN으로 업데이트) ──────────────
# aws ecs list-tasks --cluster cdci-prd-cluster --service-name cdci-prd-<service>-service --region ap-northeast-2

variable "ecs_task_arns" {
  description = "현재 실행 중인 ECS 태스크 ARN 맵 (실험 전 업데이트 필요)"
  type        = map(string)
  default = {
    users    = ""
    history  = ""
    chatbot  = ""
    analysis = ""
    frontend = ""
  }
}

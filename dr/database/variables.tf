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

variable "dr_instance_class" {
  description = "Aurora instance class for DR secondary (must match primary)"
  type        = string
  default     = "db.r5.large"
}

variable "dr_kms_key_id" {
  description = "KMS key ARN for DR region RDS encryption"
  type        = string
  default     = "arn:aws:kms:ap-northeast-1:620758375333:key/629cc7d8-49d0-4a88-a39c-1a9f852db89a"
}

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트명 (리소스 이름 prefix)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev / prd)"
  type        = string
}

variable "replication_instance_class" {
  description = "DMS 복제 인스턴스 클래스"
  type        = string
  default     = "dms.t3.medium"
}

variable "replication_instance_storage" {
  description = "DMS 복제 인스턴스 스토리지 (GB)"
  type        = number
  default     = 50
}

variable "migration_type" {
  description = "DMS 마이그레이션 유형 (full-load | cdc | full-load-and-cdc)"
  type        = string
  default     = "full-load-and-cdc"
}

variable "use_aurora" {
  description = "Aurora Cluster 사용 여부. false = RDS Single (현재), true = Aurora Cluster (나중에 전환 시)"
  type        = bool
  default     = false
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

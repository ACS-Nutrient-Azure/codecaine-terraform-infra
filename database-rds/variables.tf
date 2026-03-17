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
  description = "Environment (dev/stg/prd)"
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

# Aurora PostgreSQL Variables
variable "aurora_clusters" {
  description = "Aurora PostgreSQL cluster configurations"
  type = map(object({
    cluster_identifier      = string
    instance_class          = string
    instance_count          = number
    database_name           = string
    master_username         = string
    backup_retention        = number
    serverless_min_capacity = number
    serverless_max_capacity = number
  }))
  default = {
    cluster1 = {
      cluster_identifier      = "users-cluster"
      instance_class          = "db.serverless"
      instance_count          = 2
      database_name           = "vitamin_user"
      master_username         = "vitamin_user"
      backup_retention        = 7
      serverless_min_capacity = 0.5
      serverless_max_capacity = 2
    }
    cluster2 = {
      cluster_identifier      = "history-cluster"
      instance_class          = "db.serverless"
      instance_count          = 2
      database_name           = "vitamin_history"
      master_username         = "vitamin_history"
      backup_retention        = 7
      serverless_min_capacity = 0.5
      serverless_max_capacity = 2
    }
    cluster3 = {
      cluster_identifier      = "analysis-cluster"
      instance_class          = "db.serverless"
      instance_count          = 2
      database_name           = "vitamin_analysis"
      master_username         = "vitamin_analysis"
      backup_retention        = 7
      serverless_min_capacity = 0.5
      serverless_max_capacity = 2
    }
  }
}

variable "aurora_postgres_version" {
  description = "Aurora PostgreSQL version"
  type        = string
  default     = "15.8"
}

variable "enable_global_database" {
  description = "Enable Aurora Global Database"
  type        = bool
  default     = false
}

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

variable "dynamodb_tables" {
  description = "DynamoDB table configurations"
  type = map(object({
    hash_key         = string
    range_key        = string
    billing_mode     = string
    read_capacity    = number
    write_capacity   = number
    stream_enabled   = bool
    stream_view_type = string
    attributes = list(object({
      name = string
      type = string
    }))
    global_secondary_indexes = list(object({
      name            = string
      hash_key        = string
      range_key       = string
      projection_type = string
      read_capacity   = number
      write_capacity  = number
    }))
  }))
  default = {
    main = {
      hash_key         = "id"
      range_key        = "timestamp"
      billing_mode     = "PAY_PER_REQUEST"
      read_capacity    = 0
      write_capacity   = 0
      stream_enabled   = false
      stream_view_type = "NEW_AND_OLD_IMAGES"
      attributes = [
        {
          name = "id"
          type = "S"
        },
        {
          name = "timestamp"
          type = "N"
        },
        {
          name = "userId"
          type = "S"
        }
      ]
      global_secondary_indexes = [
        {
          name            = "UserIdIndex"
          hash_key        = "userId"
          range_key       = "timestamp"
          projection_type = "ALL"
          read_capacity   = 0
          write_capacity  = 0
        }
      ]
    }
  }
}

variable "enable_dynamodb_encryption" {
  description = "Enable DynamoDB encryption at rest"
  type        = bool
  default     = true
}

# Global Table Variables
variable "enable_global_table" {
  description = "Enable DynamoDB Global Table"
  type        = bool
  default     = false
}

variable "global_table_regions" {
  description = "List of regions for DynamoDB Global Table replicas"
  type        = list(string)
  default     = []
}

project_name = "cdci" # CodeCaine 팀 약어
environment  = "prd"
region       = "ap-northeast-2"

dynamodb_tables = {
  ChatbotData = {
    hash_key         = "id"
    range_key        = "timestamp"
    billing_mode     = "PAY_PER_REQUEST"
    read_capacity    = 0
    write_capacity   = 0
    stream_enabled   = false # Global Table 사용 시 자동으로 true
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

enable_dynamodb_encryption = true

# Global Table 설정
enable_global_table = false # Global Table 활성화 시 true
global_table_regions = [
  # "us-east-1",
  # "eu-west-1",
  # "ap-southeast-1",
]

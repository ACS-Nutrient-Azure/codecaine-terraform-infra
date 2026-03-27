project_name = "cdci" # CodeCaine 팀 약어
environment  = "prd"
region       = "ap-northeast-2"

postgres_port = 5432

# Aurora PostgreSQL (3개 클러스터 - 각각 다른 역할)
aurora_postgres_version = "15.8"
enable_global_database  = true # DR을 위한 Aurora Global Database 활성화

aurora_clusters = {
  cluster1 = {
    cluster_identifier      = "users-cluster"
    instance_class          = "db.serverless" # Serverless v2
    instance_count          = 2               # Writer 1개 + Reader 1개
    database_name           = "vitamin_user"
    master_username         = "vitamin_user"
    backup_retention        = 7
    serverless_min_capacity = 0.5 # 최소 0.5 ACU (1 ACU = 2GB RAM)
    serverless_max_capacity = 2   # 최대 2 ACU
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
  cluster4 = {
    cluster_identifier      = "chatbot-cluster"
    instance_class          = "db.serverless"
    instance_count          = 2
    database_name           = "vitamin_chatbot"
    master_username         = "vitamin_chatbot"
    backup_retention        = 7
    serverless_min_capacity = 0.5
    serverless_max_capacity = 2
  }
}

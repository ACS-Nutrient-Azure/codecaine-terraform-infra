# ============================================
# Secrets Manager - 비밀번호 자동 생성 및 관리
# ============================================

# Cluster 1: users-cluster
resource "aws_secretsmanager_secret" "cluster1" {
  name                    = "${var.project_name}-${var.environment}-users-cluster-secret"
  description             = "Users cluster master credentials (auto-generated)"
  recovery_window_in_days = 0

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-USERS-CLUSTER-SECRET"
    Cluster = "users-cluster"
  }
}

resource "aws_secretsmanager_secret_version" "cluster1" {
  secret_id = aws_secretsmanager_secret.cluster1.id
  secret_string = jsonencode({
    username = var.aurora_clusters["cluster1"].master_username
    password = random_password.cluster1.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora_cluster1.endpoint
    port     = var.postgres_port
    dbname   = var.aurora_clusters["cluster1"].database_name
  })
}

resource "random_password" "cluster1" {
  length  = 32
  special = true
  # PostgreSQL에서 사용 가능한 특수문자만 사용
  override_special = "!#$%&*()-_=+[]{}:?"
}

# Cluster 2: history-cluster
resource "aws_secretsmanager_secret" "cluster2" {
  name                    = "${var.project_name}-${var.environment}-history-cluster-secret"
  description             = "History cluster master credentials (auto-generated)"
  recovery_window_in_days = 0

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-HISTORY-CLUSTER-SECRET"
    Cluster = "history-cluster"
  }
}

resource "aws_secretsmanager_secret_version" "cluster2" {
  secret_id = aws_secretsmanager_secret.cluster2.id
  secret_string = jsonencode({
    username = var.aurora_clusters["cluster2"].master_username
    password = random_password.cluster2.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora_cluster2.endpoint
    port     = var.postgres_port
    dbname   = var.aurora_clusters["cluster2"].database_name
  })
}

resource "random_password" "cluster2" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

# Cluster 3: analysis-cluster
resource "aws_secretsmanager_secret" "cluster3" {
  name                    = "${var.project_name}-${var.environment}-analysis-cluster-secret"
  description             = "Analysis cluster master credentials (auto-generated)"
  recovery_window_in_days = 0

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-ANALYSIS-CLUSTER-SECRET"
    Cluster = "analysis-cluster"
  }
}

resource "aws_secretsmanager_secret_version" "cluster3" {
  secret_id = aws_secretsmanager_secret.cluster3.id
  secret_string = jsonencode({
    username = var.aurora_clusters["cluster3"].master_username
    password = random_password.cluster3.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora_cluster3.endpoint
    port     = var.postgres_port
    dbname   = var.aurora_clusters["cluster3"].database_name
  })
}

resource "random_password" "cluster3" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

# ============================================
# AWS 제공 Secrets Manager Rotation Lambda 사용
# ============================================
# 
# 주의: Rotation Lambda는 별도로 배포해야 합니다.
# 현재는 주석 처리되어 있으며, 필요시 아래 단계를 따르세요:
# 1. AWS Serverless Application Repository에서 Lambda 배포
# 2. 배포된 Lambda 함수 ARN으로 rotation_lambda_arn 업데이트
# 3. 주석 해제
#
# resource "aws_secretsmanager_secret_rotation" "cluster1" {
#   secret_id           = aws_secretsmanager_secret.cluster1.id
#   rotation_lambda_arn = "arn:aws:lambda:${var.region}:ACCOUNT_ID:function:SecretsManagerRotation"
#
#   rotation_rules {
#     automatically_after_days = 30
#   }
#
#   depends_on = [
#     aws_secretsmanager_secret_version.cluster1,
#     aws_rds_cluster_instance.aurora_cluster1
#   ]
# }
#
# resource "aws_secretsmanager_secret_rotation" "cluster2" {
#   secret_id           = aws_secretsmanager_secret.cluster2.id
#   rotation_lambda_arn = "arn:aws:lambda:${var.region}:ACCOUNT_ID:function:SecretsManagerRotation"
#
#   rotation_rules {
#     automatically_after_days = 30
#   }
#
#   depends_on = [
#     aws_secretsmanager_secret_version.cluster2,
#     aws_rds_cluster_instance.aurora_cluster2
#   ]
# }
#
# resource "aws_secretsmanager_secret_rotation" "cluster3" {
#   secret_id           = aws_secretsmanager_secret.cluster3.id
#   rotation_lambda_arn = "arn:aws:lambda:${var.region}:ACCOUNT_ID:function:SecretsManagerRotation"
#
#   rotation_rules {
#     automatically_after_days = 30
#   }
#
#   depends_on = [
#     aws_secretsmanager_secret_version.cluster3,
#     aws_rds_cluster_instance.aurora_cluster3
#   ]
# }

# ============================================
# SSM Parameter Store - 고정값 (엔드포인트, 포트, DB명, 사용자명)
# ============================================

# Cluster 1: users-cluster
resource "aws_ssm_parameter" "cluster1_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/users-cluster/endpoint"
  description = "Users cluster endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora_cluster1.endpoint

  tags = {
    Name = "${var.project_name}-${var.environment}-users-cluster-endpoint"
  }
}

resource "aws_ssm_parameter" "cluster1_reader_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/users-cluster/reader-endpoint"
  description = "Users cluster reader endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora_cluster1.reader_endpoint

  tags = {
    Name = "${var.project_name}-${var.environment}-users-cluster-reader-endpoint"
  }
}

resource "aws_ssm_parameter" "cluster1_port" {
  name        = "/${var.project_name}/${var.environment}/rds/users-cluster/port"
  description = "Users cluster port"
  type        = "String"
  value       = tostring(var.postgres_port)

  tags = {
    Name = "${var.project_name}-${var.environment}-users-cluster-port"
  }
}

resource "aws_ssm_parameter" "cluster1_dbname" {
  name        = "/${var.project_name}/${var.environment}/rds/users-cluster/dbname"
  description = "Users cluster database name"
  type        = "String"
  value       = var.aurora_clusters["cluster1"].database_name

  tags = {
    Name = "${var.project_name}-${var.environment}-users-cluster-dbname"
  }
}

resource "aws_ssm_parameter" "cluster1_username" {
  name        = "/${var.project_name}/${var.environment}/rds/users-cluster/username"
  description = "Users cluster master username"
  type        = "String"
  value       = var.aurora_clusters["cluster1"].master_username

  tags = {
    Name = "${var.project_name}-${var.environment}-users-cluster-username"
  }
}

# Cluster 2: history-cluster
resource "aws_ssm_parameter" "cluster2_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/history-cluster/endpoint"
  description = "History cluster endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora_cluster2.endpoint

  tags = {
    Name = "${var.project_name}-${var.environment}-history-cluster-endpoint"
  }
}

resource "aws_ssm_parameter" "cluster2_reader_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/history-cluster/reader-endpoint"
  description = "History cluster reader endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora_cluster2.reader_endpoint

  tags = {
    Name = "${var.project_name}-${var.environment}-history-cluster-reader-endpoint"
  }
}

resource "aws_ssm_parameter" "cluster2_port" {
  name        = "/${var.project_name}/${var.environment}/rds/history-cluster/port"
  description = "History cluster port"
  type        = "String"
  value       = tostring(var.postgres_port)

  tags = {
    Name = "${var.project_name}-${var.environment}-history-cluster-port"
  }
}

resource "aws_ssm_parameter" "cluster2_dbname" {
  name        = "/${var.project_name}/${var.environment}/rds/history-cluster/dbname"
  description = "History cluster database name"
  type        = "String"
  value       = var.aurora_clusters["cluster2"].database_name

  tags = {
    Name = "${var.project_name}-${var.environment}-history-cluster-dbname"
  }
}

resource "aws_ssm_parameter" "cluster2_username" {
  name        = "/${var.project_name}/${var.environment}/rds/history-cluster/username"
  description = "History cluster master username"
  type        = "String"
  value       = var.aurora_clusters["cluster2"].master_username

  tags = {
    Name = "${var.project_name}-${var.environment}-history-cluster-username"
  }
}

# Cluster 3: analysis-cluster
resource "aws_ssm_parameter" "cluster3_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/analysis-cluster/endpoint"
  description = "Analysis cluster endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora_cluster3.endpoint

  tags = {
    Name = "${var.project_name}-${var.environment}-analysis-cluster-endpoint"
  }
}

resource "aws_ssm_parameter" "cluster3_reader_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/analysis-cluster/reader-endpoint"
  description = "Analysis cluster reader endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora_cluster3.reader_endpoint

  tags = {
    Name = "${var.project_name}-${var.environment}-analysis-cluster-reader-endpoint"
  }
}

resource "aws_ssm_parameter" "cluster3_port" {
  name        = "/${var.project_name}/${var.environment}/rds/analysis-cluster/port"
  description = "Analysis cluster port"
  type        = "String"
  value       = tostring(var.postgres_port)

  tags = {
    Name = "${var.project_name}-${var.environment}-analysis-cluster-port"
  }
}

resource "aws_ssm_parameter" "cluster3_dbname" {
  name        = "/${var.project_name}/${var.environment}/rds/analysis-cluster/dbname"
  description = "Analysis cluster database name"
  type        = "String"
  value       = var.aurora_clusters["cluster3"].database_name

  tags = {
    Name = "${var.project_name}-${var.environment}-analysis-cluster-dbname"
  }
}

resource "aws_ssm_parameter" "cluster3_username" {
  name        = "/${var.project_name}/${var.environment}/rds/analysis-cluster/username"
  description = "Analysis cluster master username"
  type        = "String"
  value       = var.aurora_clusters["cluster3"].master_username

  tags = {
    Name = "${var.project_name}-${var.environment}-analysis-cluster-username"
  }
}

# Cluster 4: chatbot-cluster
resource "aws_secretsmanager_secret" "cluster4" {
  name                    = "${var.project_name}-${var.environment}-chatbot-cluster-secret"
  description             = "Chatbot cluster master credentials (auto-generated)"
  recovery_window_in_days = 0

  tags = {
    Name    = "${upper(var.project_name)}-${upper(var.environment)}-CHATBOT-CLUSTER-SECRET"
    Cluster = "chatbot-cluster"
  }
}

resource "aws_secretsmanager_secret_version" "cluster4" {
  secret_id = aws_secretsmanager_secret.cluster4.id
  secret_string = jsonencode({
    username = var.aurora_clusters["cluster4"].master_username
    password = random_password.cluster4.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora_cluster4.endpoint
    port     = var.postgres_port
    dbname   = var.aurora_clusters["cluster4"].database_name
  })
}

resource "random_password" "cluster4" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

resource "aws_ssm_parameter" "cluster4_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/chatbot-cluster/endpoint"
  description = "Chatbot cluster endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora_cluster4.endpoint

  tags = {
    Name = "${var.project_name}-${var.environment}-chatbot-cluster-endpoint"
  }
}

resource "aws_ssm_parameter" "cluster4_reader_endpoint" {
  name        = "/${var.project_name}/${var.environment}/rds/chatbot-cluster/reader-endpoint"
  description = "Chatbot cluster reader endpoint"
  type        = "String"
  value       = aws_rds_cluster.aurora_cluster4.reader_endpoint

  tags = {
    Name = "${var.project_name}-${var.environment}-chatbot-cluster-reader-endpoint"
  }
}

resource "aws_ssm_parameter" "cluster4_port" {
  name        = "/${var.project_name}/${var.environment}/rds/chatbot-cluster/port"
  description = "Chatbot cluster port"
  type        = "String"
  value       = tostring(var.postgres_port)

  tags = {
    Name = "${var.project_name}-${var.environment}-chatbot-cluster-port"
  }
}

resource "aws_ssm_parameter" "cluster4_dbname" {
  name        = "/${var.project_name}/${var.environment}/rds/chatbot-cluster/dbname"
  description = "Chatbot cluster database name"
  type        = "String"
  value       = var.aurora_clusters["cluster4"].database_name

  tags = {
    Name = "${var.project_name}-${var.environment}-chatbot-cluster-dbname"
  }
}

resource "aws_ssm_parameter" "cluster4_username" {
  name        = "/${var.project_name}/${var.environment}/rds/chatbot-cluster/username"
  description = "Chatbot cluster master username"
  type        = "String"
  value       = var.aurora_clusters["cluster4"].master_username

  tags = {
    Name = "${var.project_name}-${var.environment}-chatbot-cluster-username"
  }
}

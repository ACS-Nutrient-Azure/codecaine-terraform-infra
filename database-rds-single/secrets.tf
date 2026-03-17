# ============================================
# Random Passwords
# ============================================
resource "random_password" "users" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

resource "random_password" "history" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

resource "random_password" "analysis" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

# ============================================
# Secrets Manager
# ============================================
resource "aws_secretsmanager_secret" "users" {
  name                    = "${var.project_name}-${var.environment}-users-cluster-secret"
  description             = "Users RDS credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-USERS-CLUSTER-SECRET"
  }
}

resource "aws_secretsmanager_secret_version" "users" {
  secret_id = aws_secretsmanager_secret.users.id
  secret_string = jsonencode({
    username = aws_db_instance.users.username
    password = random_password.users.result
    engine   = "postgres"
    host     = aws_db_instance.users.address
    port     = var.postgres_port
    dbname   = aws_db_instance.users.db_name
  })
}

resource "aws_secretsmanager_secret" "history" {
  name                    = "${var.project_name}-${var.environment}-history-cluster-secret"
  description             = "History RDS credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-HISTORY-CLUSTER-SECRET"
  }
}

resource "aws_secretsmanager_secret_version" "history" {
  secret_id = aws_secretsmanager_secret.history.id
  secret_string = jsonencode({
    username = aws_db_instance.history.username
    password = random_password.history.result
    engine   = "postgres"
    host     = aws_db_instance.history.address
    port     = var.postgres_port
    dbname   = aws_db_instance.history.db_name
  })
}

resource "aws_secretsmanager_secret" "analysis" {
  name                    = "${var.project_name}-${var.environment}-analysis-cluster-secret"
  description             = "Analysis RDS credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ANALYSIS-CLUSTER-SECRET"
  }
}

resource "aws_secretsmanager_secret_version" "analysis" {
  secret_id = aws_secretsmanager_secret.analysis.id
  secret_string = jsonencode({
    username = aws_db_instance.analysis.username
    password = random_password.analysis.result
    engine   = "postgres"
    host     = aws_db_instance.analysis.address
    port     = var.postgres_port
    dbname   = aws_db_instance.analysis.db_name
  })
}

# ============================================
# SSM Parameter Store
# ============================================

# users
resource "aws_ssm_parameter" "users_endpoint" {
  name  = "/${var.project_name}/${var.environment}/rds/users-cluster/endpoint"
  type  = "String"
  value = aws_db_instance.users.address
  tags  = { Name = "${var.project_name}-${var.environment}-users-endpoint" }
}

resource "aws_ssm_parameter" "users_port" {
  name  = "/${var.project_name}/${var.environment}/rds/users-cluster/port"
  type  = "String"
  value = tostring(var.postgres_port)
  tags  = { Name = "${var.project_name}-${var.environment}-users-port" }
}

resource "aws_ssm_parameter" "users_dbname" {
  name  = "/${var.project_name}/${var.environment}/rds/users-cluster/dbname"
  type  = "String"
  value = aws_db_instance.users.db_name
  tags  = { Name = "${var.project_name}-${var.environment}-users-dbname" }
}

resource "aws_ssm_parameter" "users_username" {
  name  = "/${var.project_name}/${var.environment}/rds/users-cluster/username"
  type  = "String"
  value = aws_db_instance.users.username
  tags  = { Name = "${var.project_name}-${var.environment}-users-username" }
}

# history
resource "aws_ssm_parameter" "history_endpoint" {
  name  = "/${var.project_name}/${var.environment}/rds/history-cluster/endpoint"
  type  = "String"
  value = aws_db_instance.history.address
  tags  = { Name = "${var.project_name}-${var.environment}-history-endpoint" }
}

resource "aws_ssm_parameter" "history_port" {
  name  = "/${var.project_name}/${var.environment}/rds/history-cluster/port"
  type  = "String"
  value = tostring(var.postgres_port)
  tags  = { Name = "${var.project_name}-${var.environment}-history-port" }
}

resource "aws_ssm_parameter" "history_dbname" {
  name  = "/${var.project_name}/${var.environment}/rds/history-cluster/dbname"
  type  = "String"
  value = aws_db_instance.history.db_name
  tags  = { Name = "${var.project_name}-${var.environment}-history-dbname" }
}

resource "aws_ssm_parameter" "history_username" {
  name  = "/${var.project_name}/${var.environment}/rds/history-cluster/username"
  type  = "String"
  value = aws_db_instance.history.username
  tags  = { Name = "${var.project_name}-${var.environment}-history-username" }
}

# analysis
resource "aws_ssm_parameter" "analysis_endpoint" {
  name  = "/${var.project_name}/${var.environment}/rds/analysis-cluster/endpoint"
  type  = "String"
  value = aws_db_instance.analysis.address
  tags  = { Name = "${var.project_name}-${var.environment}-analysis-endpoint" }
}

resource "aws_ssm_parameter" "analysis_port" {
  name  = "/${var.project_name}/${var.environment}/rds/analysis-cluster/port"
  type  = "String"
  value = tostring(var.postgres_port)
  tags  = { Name = "${var.project_name}-${var.environment}-analysis-port" }
}

resource "aws_ssm_parameter" "analysis_dbname" {
  name  = "/${var.project_name}/${var.environment}/rds/analysis-cluster/dbname"
  type  = "String"
  value = aws_db_instance.analysis.db_name
  tags  = { Name = "${var.project_name}-${var.environment}-analysis-dbname" }
}

resource "aws_ssm_parameter" "analysis_username" {
  name  = "/${var.project_name}/${var.environment}/rds/analysis-cluster/username"
  type  = "String"
  value = aws_db_instance.analysis.username
  tags  = { Name = "${var.project_name}-${var.environment}-analysis-username" }
}

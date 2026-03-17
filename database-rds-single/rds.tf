# DB Parameter Group (공통)
resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${var.project_name}-${var.environment}-postgres15-"
  family      = "postgres15"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-POSTGRES15-PARAMS"
  }
}

# ============================================
# RDS 1: users
# ============================================
resource "aws_db_instance" "users" {
  identifier        = "${var.project_name}-${var.environment}-users"
  engine            = "postgres"
  engine_version    = var.postgres_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = "vitamin_user"
  username = "vitamin_user"
  password = random_password.users.result
  port     = var.postgres_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [local.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  multi_az                = var.multi_az
  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-USERS-RDS"
  }
}

# ============================================
# RDS 2: history
# ============================================
resource "aws_db_instance" "history" {
  identifier        = "${var.project_name}-${var.environment}-history"
  engine            = "postgres"
  engine_version    = var.postgres_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = "vitamin_history"
  username = "vitamin_history"
  password = random_password.history.result
  port     = var.postgres_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [local.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  multi_az                = var.multi_az
  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-HISTORY-RDS"
  }
}

# ============================================
# RDS 3: analysis
# ============================================
resource "aws_db_instance" "analysis" {
  identifier        = "${var.project_name}-${var.environment}-analysis"
  engine            = "postgres"
  engine_version    = var.postgres_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = "vitamin_analysis"
  username = "vitamin_analysis"
  password = random_password.analysis.result
  port     = var.postgres_port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [local.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  multi_az                = var.multi_az
  publicly_accessible     = false
  storage_encrypted       = true
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-ANALYSIS-RDS"
  }
}

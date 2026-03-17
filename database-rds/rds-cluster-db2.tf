# Aurora Cluster: history-cluster
# 비밀번호는 secrets.tf에서 관리됩니다

# Aurora Global Database (Primary Region)
resource "aws_rds_global_cluster" "aurora_cluster2" {
  count = var.enable_global_database ? 1 : 0

  global_cluster_identifier = "${var.project_name}-${var.environment}-${var.aurora_clusters["cluster2"].cluster_identifier}-global"
  engine                    = "aurora-postgresql"
  engine_version            = var.aurora_postgres_version
  database_name             = var.aurora_clusters["cluster2"].database_name
  storage_encrypted         = true
}

# Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "aurora_cluster2" {
  cluster_identifier = "${var.project_name}-${var.environment}-${var.aurora_clusters["cluster2"].cluster_identifier}"
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_postgres_version
  engine_mode        = "provisioned"
  database_name      = var.aurora_clusters["cluster2"].database_name
  master_username    = var.aurora_clusters["cluster2"].master_username
  master_password    = random_password.cluster2.result
  port               = var.postgres_port

  global_cluster_identifier = var.enable_global_database ? aws_rds_global_cluster.aurora_cluster2[0].id : null

  db_subnet_group_name            = local.db_subnet_group_name
  vpc_security_group_ids          = [local.rds_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  backup_retention_period      = var.aurora_clusters["cluster2"].backup_retention
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  storage_encrypted = true

  skip_final_snapshot       = var.environment == "dev" ? true : false
  final_snapshot_identifier = var.environment == "dev" ? null : "${var.project_name}-${var.environment}-${var.aurora_clusters["cluster2"].cluster_identifier}-final-snapshot"

  deletion_protection = var.environment == "prd" ? true : false

  serverlessv2_scaling_configuration {
    max_capacity = var.aurora_clusters["cluster2"].serverless_max_capacity
    min_capacity = var.aurora_clusters["cluster2"].serverless_min_capacity
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.aurora_clusters["cluster2"].cluster_identifier}"
  }

  lifecycle {
    ignore_changes = [
      global_cluster_identifier
    ]
  }
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "aurora_cluster2" {
  count = var.aurora_clusters["cluster2"].instance_count

  # 첫 번째 인스턴스는 Writer(wo), 나머지는 Reader(ro)
  identifier              = "${var.project_name}-${var.environment}-${var.aurora_clusters["cluster2"].cluster_identifier}-${count.index == 0 ? "wo" : "ro"}"
  cluster_identifier      = aws_rds_cluster.aurora_cluster2.id
  instance_class          = var.aurora_clusters["cluster2"].instance_class
  engine                  = "aurora-postgresql"
  engine_version          = var.aurora_postgres_version
  db_parameter_group_name = aws_db_parameter_group.aurora.name

  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.aurora_clusters["cluster2"].cluster_identifier}-${count.index == 0 ? "wo" : "ro"}"
    Role = count.index == 0 ? "Writer" : "Reader"
  }
}

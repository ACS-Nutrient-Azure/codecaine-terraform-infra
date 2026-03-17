# Aurora DB Cluster Parameter Group (공통)
resource "aws_rds_cluster_parameter_group" "aurora" {
  name_prefix = "${var.project_name}-${var.environment}-aurora-cluster-"
  family      = "aurora-postgresql15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-cluster-params"
  }
}

# Aurora DB Parameter Group (공통)
resource "aws_db_parameter_group" "aurora" {
  name_prefix = "${var.project_name}-${var.environment}-aurora-"
  family      = "aurora-postgresql15"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-params"
  }
}

# Enhanced Monitoring IAM Role (공통)
resource "aws_iam_role" "rds_monitoring" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-RDS-MONITORING-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-RDS-MONITORING-ROLE"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

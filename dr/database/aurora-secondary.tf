# Aurora Global Database Secondary Clusters (도쿄)
# Primary에서 enable_global_database = true 로 Global Cluster가 생성된 후 연결
#
# 주의: Primary의 database-rds 모듈에서 enable_global_database = true 설정 후
#       terraform apply 완료 → 그 다음 이 모듈 apply

locals {
  db_subnet_group_name = data.terraform_remote_state.dr_foundation.outputs.db_subnet_group_name
  rds_sg_id            = data.terraform_remote_state.dr_foundation.outputs.rds_security_group_id

  clusters = {
    cluster1 = {
      identifier = "users-cluster"
      db_name    = "vitamin_user"
    }
    cluster2 = {
      identifier = "history-cluster"
      db_name    = "vitamin_history"
    }
    cluster3 = {
      identifier = "analysis-cluster"
      db_name    = "vitamin_analysis"
    }
    cluster4 = {
      identifier = "chatbot-cluster"
      db_name    = "vitamin_chatbot"
    }
  }
}

# ── cluster1: users ───────────────────────────────────────────────

resource "aws_rds_cluster" "dr_cluster1" {
  cluster_identifier        = "${var.project_name}-${var.environment}-dr-users-cluster"
  engine                    = "aurora-postgresql"
  engine_version            = var.aurora_postgres_version
  engine_mode               = "provisioned"
  global_cluster_identifier = data.terraform_remote_state.primary_db.outputs.aurora_global_cluster_ids["cluster1"]

  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = [local.rds_sg_id]
  kms_key_id             = var.dr_kms_key_id
  storage_encrypted      = true

  # Secondary는 master_username/password 불필요 (Global DB가 복제)
  skip_final_snapshot = true
  deletion_protection = false

  lifecycle {
    ignore_changes = [replication_source_identifier, global_cluster_identifier]
  }

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-USERS-CLUSTER" }
}

resource "aws_rds_cluster_instance" "dr_cluster1" {
  identifier         = "${var.project_name}-${var.environment}-dr-users-cluster-ro"
  cluster_identifier = aws_rds_cluster.dr_cluster1.id
  instance_class     = var.dr_instance_class
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_postgres_version

  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-USERS-CLUSTER-RO" }
}

# ── cluster2: history ─────────────────────────────────────────────

resource "aws_rds_cluster" "dr_cluster2" {
  cluster_identifier        = "${var.project_name}-${var.environment}-dr-history-cluster"
  engine                    = "aurora-postgresql"
  engine_version            = var.aurora_postgres_version
  engine_mode               = "provisioned"
  global_cluster_identifier = data.terraform_remote_state.primary_db.outputs.aurora_global_cluster_ids["cluster2"]

  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = [local.rds_sg_id]
  kms_key_id             = var.dr_kms_key_id
  storage_encrypted      = true

  skip_final_snapshot = true
  deletion_protection = false

  lifecycle {
    ignore_changes = [replication_source_identifier, global_cluster_identifier]
  }

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-HISTORY-CLUSTER" }
}

resource "aws_rds_cluster_instance" "dr_cluster2" {
  identifier         = "${var.project_name}-${var.environment}-dr-history-cluster-ro"
  cluster_identifier = aws_rds_cluster.dr_cluster2.id
  instance_class     = var.dr_instance_class
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_postgres_version

  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-HISTORY-CLUSTER-RO" }
}

# ── cluster3: analysis ────────────────────────────────────────────

resource "aws_rds_cluster" "dr_cluster3" {
  cluster_identifier        = "${var.project_name}-${var.environment}-dr-analysis-cluster"
  engine                    = "aurora-postgresql"
  engine_version            = var.aurora_postgres_version
  engine_mode               = "provisioned"
  global_cluster_identifier = data.terraform_remote_state.primary_db.outputs.aurora_global_cluster_ids["cluster3"]

  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = [local.rds_sg_id]
  kms_key_id             = var.dr_kms_key_id
  storage_encrypted      = true

  skip_final_snapshot = true
  deletion_protection = false

  lifecycle {
    ignore_changes = [replication_source_identifier, global_cluster_identifier]
  }

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ANALYSIS-CLUSTER" }
}

resource "aws_rds_cluster_instance" "dr_cluster3" {
  identifier         = "${var.project_name}-${var.environment}-dr-analysis-cluster-ro"
  cluster_identifier = aws_rds_cluster.dr_cluster3.id
  instance_class     = var.dr_instance_class
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_postgres_version

  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ANALYSIS-CLUSTER-RO" }
}

# ── cluster4: chatbot ─────────────────────────────────────────────

resource "aws_rds_cluster" "dr_cluster4" {
  cluster_identifier        = "${var.project_name}-${var.environment}-dr-chatbot-cluster"
  engine                    = "aurora-postgresql"
  engine_version            = var.aurora_postgres_version
  engine_mode               = "provisioned"
  global_cluster_identifier = data.terraform_remote_state.primary_db.outputs.aurora_global_cluster_ids["cluster4"]

  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = [local.rds_sg_id]
  kms_key_id             = var.dr_kms_key_id
  storage_encrypted      = true

  skip_final_snapshot = true
  deletion_protection = false

  lifecycle {
    ignore_changes = [replication_source_identifier, global_cluster_identifier]
  }

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-CHATBOT-CLUSTER" }
}

resource "aws_rds_cluster_instance" "dr_cluster4" {
  identifier         = "${var.project_name}-${var.environment}-dr-chatbot-cluster-ro"
  cluster_identifier = aws_rds_cluster.dr_cluster4.id
  instance_class     = var.dr_instance_class
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_postgres_version

  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-CHATBOT-CLUSTER-RO" }
}

# ── Enhanced Monitoring Role ──────────────────────────────────────

resource "aws_iam_role" "rds_monitoring" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-DR-RDS-MONITORING-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

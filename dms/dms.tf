# ============================================================
# [사전 조건] users RDS Logical Replication 활성화용 파라미터 그룹
# ============================================================
# use_aurora = false (RDS Single, 현재):
#   aws rds modify-db-instance \
#     --db-instance-identifier cdci-prd-users \
#     --db-parameter-group-name <output: users_logical_param_group_name> \
#     --apply-immediately
#   aws rds reboot-db-instance --db-instance-identifier cdci-prd-users
#
# use_aurora = true (Aurora Cluster, 나중에 전환 시):
#   aws rds modify-db-cluster \
#     --db-cluster-identifier cdci-prd-users-cluster \
#     --db-cluster-parameter-group-name <output: users_logical_param_group_name> \
#     --apply-immediately
#   aws rds reboot-db-instance --db-instance-identifier cdci-prd-users-cluster-wo
# ============================================================

# RDS Single용 파라미터 그룹 (use_aurora = false)
resource "aws_db_parameter_group" "users_logical" {
  count       = var.use_aurora ? 0 : 1
  name_prefix = "${local.name_prefix}-users-logical-"
  family      = "postgres15"
  description = "users RDS DMS CDC - logical replication enabled"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-users-logical-params"
  }
}

# Aurora Cluster용 파라미터 그룹 (use_aurora = true)
resource "aws_rds_cluster_parameter_group" "users_logical" {
  count       = var.use_aurora ? 1 : 0
  name_prefix = "${local.name_prefix}-users-logical-aurora-"
  family      = "aurora-postgresql15"
  description = "users Aurora DMS CDC - logical replication enabled"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-users-logical-aurora-params"
  }
}

# ============================================================
# DMS Security Group
# ============================================================

resource "aws_security_group" "dms" {
  name        = "${local.name_prefix}-dms-sg"
  description = "DMS Replication Instance Security Group"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound for RDS access"
  }

  tags = {
    Name = "${local.name_prefix}-dms-sg"
  }
}

# RDS SG에 DMS SG → 5432 인바운드 허용 규칙 추가 (공통 SG 하나)
resource "aws_security_group_rule" "rds_allow_dms" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = local.rds_users_sg_id
  source_security_group_id = aws_security_group.dms.id
  description              = "DMS Replication Instance to RDS"
}

# ============================================================
# DMS Replication Subnet Group
# ============================================================

resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "${local.name_prefix}-dms-subnet-group"
  replication_subnet_group_description = "DMS subnet group (private DB subnets)"
  subnet_ids                           = local.private_db_subnet_ids

  tags = {
    Name = "${local.name_prefix}-dms-subnet-group"
  }

  depends_on = [aws_iam_role.dms_vpc_role]
}

# ============================================================
# DMS Replication Instance
# ============================================================

resource "aws_dms_replication_instance" "main" {
  replication_instance_id    = "${local.name_prefix}-dms-instance"
  replication_instance_class = var.replication_instance_class
  allocated_storage          = var.replication_instance_storage

  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  engine_version             = "3.5.4"
  auto_minor_version_upgrade = true
  multi_az                   = false
  publicly_accessible        = false
  apply_immediately          = true

  tags = {
    Name = "${local.name_prefix}-dms-instance"
  }

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role,
    aws_iam_role_policy_attachment.dms_cloudwatch_role,
  ]
}

# ============================================================
# Source Endpoint: users-cluster (vitamin_user)
# ============================================================

resource "aws_dms_endpoint" "source_users" {
  endpoint_id   = "${local.name_prefix}-src-users"
  endpoint_type = "source"
  engine_name   = var.use_aurora ? "aurora-postgresql" : "postgres"

  server_name   = local.users_secret["host"]
  port          = local.users_secret["port"]
  database_name = local.users_secret["dbname"]
  username      = local.users_secret["username"]
  password      = local.users_secret["password"]

  ssl_mode = "require"

  # Aurora PostgreSQL CDC 필수 설정
  # pglogical은 별도 설치 필요. RDS 기본 내장 test_decoding 사용
  extra_connection_attributes = "heartbeatFrequency=1;pluginName=test_decoding"

  tags = {
    Name = "${local.name_prefix}-src-users"
  }
}

# ============================================================
# Target Endpoint: analysis-cluster (vitamin_analysis)
# ============================================================

resource "aws_dms_endpoint" "target_analysis" {
  endpoint_id   = "${local.name_prefix}-tgt-analysis"
  endpoint_type = "target"
  engine_name   = var.use_aurora ? "aurora-postgresql" : "postgres"

  server_name   = local.analysis_secret["host"]
  port          = local.analysis_secret["port"]
  database_name = local.analysis_secret["dbname"]
  username      = local.analysis_secret["username"]
  password      = local.analysis_secret["password"]

  ssl_mode = "require"

  # source에 없는 컬럼(ans_current_conditions 등)이 target에 있어도 COPY 실패 방지
  extra_connection_attributes = "maxFileSize=512000;executeTimeout=300"

  tags = {
    Name = "${local.name_prefix}-tgt-analysis"
  }
}

# ============================================================
# Target Endpoint: history-cluster (vitamin_history)
# ============================================================

resource "aws_dms_endpoint" "target_history" {
  endpoint_id   = "${local.name_prefix}-tgt-history"
  endpoint_type = "target"
  engine_name   = var.use_aurora ? "aurora-postgresql" : "postgres"

  server_name   = local.history_secret["host"]
  port          = local.history_secret["port"]
  database_name = local.history_secret["dbname"]
  username      = local.history_secret["username"]
  password      = local.history_secret["password"]

  ssl_mode = "require"

  tags = {
    Name = "${local.name_prefix}-tgt-history"
  }
}

# ============================================================
# Target Endpoint: chatbot-cluster (vitamin_chatbot)
# ============================================================

resource "aws_dms_endpoint" "target_chatbot" {
  endpoint_id   = "${local.name_prefix}-tgt-chatbot"
  endpoint_type = "target"
  engine_name   = var.use_aurora ? "aurora-postgresql" : "postgres"

  server_name   = local.chatbot_secret["host"]
  port          = local.chatbot_secret["port"]
  database_name = local.chatbot_secret["dbname"]
  username      = local.chatbot_secret["username"]
  password      = local.chatbot_secret["password"]

  ssl_mode = "require"

  extra_connection_attributes = "maxFileSize=512000;executeTimeout=300"

  tags = {
    Name = "${local.name_prefix}-tgt-chatbot"
  }
}

# ============================================================
# Source Endpoint: analysis-cluster (analysis → chatbot 복제용)
# ============================================================

resource "aws_dms_endpoint" "source_analysis" {
  endpoint_id   = "${local.name_prefix}-src-analysis"
  endpoint_type = "source"
  engine_name   = var.use_aurora ? "aurora-postgresql" : "postgres"

  server_name   = local.analysis_secret["host"]
  port          = local.analysis_secret["port"]
  database_name = local.analysis_secret["dbname"]
  username      = local.analysis_secret["username"]
  password      = local.analysis_secret["password"]

  ssl_mode = "require"

  extra_connection_attributes = "heartbeatFrequency=1;pluginName=test_decoding"

  tags = {
    Name = "${local.name_prefix}-src-analysis"
  }
}

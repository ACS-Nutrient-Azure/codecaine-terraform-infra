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

# RDS SG에 DMS SG → 5432 인바운드 허용 규칙 추가
resource "aws_security_group_rule" "rds_allow_dms" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = local.rds_sg_id
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

  engine_version               = "3.5.4"
  auto_minor_version_upgrade   = true
  multi_az                     = false
  publicly_accessible          = false
  apply_immediately            = true

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
  engine_name   = "aurora-postgresql"

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
  engine_name   = "aurora-postgresql"

  server_name   = local.analysis_secret["host"]
  port          = local.analysis_secret["port"]
  database_name = local.analysis_secret["dbname"]
  username      = local.analysis_secret["username"]
  password      = local.analysis_secret["password"]

  ssl_mode = "require"

  tags = {
    Name = "${local.name_prefix}-tgt-analysis"
  }
}

# ============================================================
# Replication Task
# user_profile       → analysis_userdata
# current_supplements → analysis_supplements
# current_ingredients → anaysis_current_ingredients
# ============================================================

resource "aws_dms_replication_task" "user_to_analysis" {
  replication_task_id      = "${local.name_prefix}-user-to-analysis"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_users.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_analysis.endpoint_arn
  migration_type           = var.migration_type

  replication_task_settings = jsonencode({
    TargetMetadata = {
      SupportLobs        = true
      FullLobMode        = false
      LimitedSizeLobMode = true
      LobMaxSize         = 32768
    }
    FullLoadSettings = {
      TargetTablePrepMode       = "DO_NOTHING"
      CreatePkAfterFullLoad     = false
      StopTaskCachedChangesApplied = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks       = 8
      TransactionConsistencyTimeout = 600
      CommitRate                = 50000
    }
    Logging = {
      EnableLogging = true
      LogComponents = [
        { Id = "SOURCE_UNLOAD", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "TARGET_LOAD", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "TASK_MANAGER", Severity = "LOGGER_SEVERITY_DEFAULT" },
      ]
    }
  })

  table_mappings = jsonencode({
    rules = [

      # ── Selection Rules ──────────────────────────────────────────

      {
        rule-type   = "selection"
        rule-id     = "1"
        rule-name   = "sel-user-profile"
        rule-action = "include"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
        }
      },
      {
        rule-type   = "selection"
        rule-id     = "2"
        rule-name   = "sel-current-supplements"
        rule-action = "include"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
        }
      },
      {
        rule-type   = "selection"
        rule-id     = "3"
        rule-name   = "sel-current-ingredients"
        rule-action = "include"
        object-locator = {
          schema-name = "public"
          table-name  = "current_ingredients"
        }
      },

      # ── user_profile → analysis_userdata ─────────────────────────

      {
        rule-type   = "transformation"
        rule-id     = "101"
        rule-name   = "rename-table-user-profile"
        rule-action = "rename"
        rule-target = "table"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
        }
        value = "analysis_userdata"
      },
      {
        rule-type   = "transformation"
        rule-id     = "102"
        rule-name   = "rename-birth-dt"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "birth_dt"
        }
        value = "ans_birth_dt"
      },
      {
        rule-type   = "transformation"
        rule-id     = "103"
        rule-name   = "rename-gender"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "gender"
        }
        value = "ans_gender"
      },
      {
        rule-type   = "transformation"
        rule-id     = "104"
        rule-name   = "rename-height"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "height"
        }
        value = "ans_height"
      },
      {
        rule-type   = "transformation"
        rule-id     = "105"
        rule-name   = "rename-weight"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "weight"
        }
        value = "ans_weight"
      },
      {
        rule-type   = "transformation"
        rule-id     = "106"
        rule-name   = "rename-allergies"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "allergies"
        }
        value = "ans_allergies"
      },
      {
        rule-type   = "transformation"
        rule-id     = "107"
        rule-name   = "rename-chron-diseases"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "chron_diseases"
        }
        value = "ans_chron_diseases"
      },
      # analysis_userdata에 없는 컬럼 제거
      {
        rule-type   = "transformation"
        rule-id     = "108"
        rule-name   = "remove-profile-id"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "profile_id"
        }
      },
      {
        rule-type   = "transformation"
        rule-id     = "109"
        rule-name   = "remove-name"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "name"
        }
      },
      {
        rule-type   = "transformation"
        rule-id     = "110"
        rule-name   = "remove-phone"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "user_profile"
          column-name = "phone"
        }
      },

      # ── current_supplements → analysis_supplements ───────────────

      {
        rule-type   = "transformation"
        rule-id     = "201"
        rule-name   = "rename-table-current-supplements"
        rule-action = "rename"
        rule-target = "table"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
        }
        value = "analysis_supplements"
      },
      {
        rule-type   = "transformation"
        rule-id     = "202"
        rule-name   = "rename-current-id"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "current_id"
        }
        value = "ans_current_id"
      },
      {
        rule-type   = "transformation"
        rule-id     = "203"
        rule-name   = "rename-product-name"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "product_name"
        }
        value = "ans_product_name"
      },
      {
        rule-type   = "transformation"
        rule-id     = "204"
        rule-name   = "rename-serving-amount"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "serving_amount"
        }
        value = "ans_serving_amount"
      },
      {
        rule-type   = "transformation"
        rule-id     = "205"
        rule-name   = "rename-serving-per-day"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "serving_per_day"
        }
        value = "ans_serving_per_day"
      },
      {
        rule-type   = "transformation"
        rule-id     = "206"
        rule-name   = "rename-daily-total-amount"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "daily_total_amount"
        }
        value = "ans_daily_total_amount"
      },
      {
        rule-type   = "transformation"
        rule-id     = "207"
        rule-name   = "rename-is-active"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "is_active"
        }
        value = "ans_is_active"
      },
      {
        rule-type   = "transformation"
        rule-id     = "208"
        rule-name   = "rename-ingredients"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "ingredients"
        }
        value = "ans_ingredients"
      },
      # analysis_supplements에 없는 컬럼 제거
      {
        rule-type   = "transformation"
        rule-id     = "209"
        rule-name   = "remove-total-quantity"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "total_quantity"
        }
      },
      {
        rule-type   = "transformation"
        rule-id     = "210"
        rule-name   = "remove-purchased-dt"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "purchased_dt"
        }
      },
      {
        rule-type   = "transformation"
        rule-id     = "211"
        rule-name   = "remove-estimated-end-dt"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "estimated_end_dt"
        }
      },
      {
        rule-type   = "transformation"
        rule-id     = "212"
        rule-name   = "remove-start-dt"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "start_dt"
        }
      },
      {
        rule-type   = "transformation"
        rule-id     = "213"
        rule-name   = "remove-end-dt"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "end_dt"
        }
      },

      # ── current_ingredients → anaysis_current_ingredients ────────

      {
        rule-type   = "transformation"
        rule-id     = "301"
        rule-name   = "rename-table-current-ingredients"
        rule-action = "rename"
        rule-target = "table"
        object-locator = {
          schema-name = "public"
          table-name  = "current_ingredients"
        }
        value = "anaysis_current_ingredients"
      },
      {
        rule-type   = "transformation"
        rule-id     = "302"
        rule-name   = "rename-ingredient-id"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_ingredients"
          column-name = "ingredient_id"
        }
        value = "ans_ingredient_id"
      },
      {
        rule-type   = "transformation"
        rule-id     = "303"
        rule-name   = "rename-ci-current-id"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_ingredients"
          column-name = "current_id"
        }
        value = "ans_current_id"
      },
      {
        rule-type   = "transformation"
        rule-id     = "304"
        rule-name   = "rename-ingredient-name"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_ingredients"
          column-name = "ingredient_name"
        }
        value = "ans_ingredient_name"
      },
      {
        rule-type   = "transformation"
        rule-id     = "305"
        rule-name   = "rename-nutrient-amount"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_ingredients"
          column-name = "nutrient_amount"
        }
        value = "ans_nutrient_amount"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-user-to-analysis"
  }
}

# ============================================================
# Target Endpoint: history-cluster (vitamin_history)
# ============================================================

resource "aws_dms_endpoint" "target_history" {
  endpoint_id   = "${local.name_prefix}-tgt-history"
  endpoint_type = "target"
  engine_name   = "aurora-postgresql"

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
# Replication Task: users → history
# current_supplements → intake_supplements
# ============================================================

resource "aws_dms_replication_task" "users_to_history" {
  replication_task_id      = "${local.name_prefix}-users-to-history"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_users.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_history.endpoint_arn
  migration_type           = var.migration_type

  replication_task_settings = jsonencode({
    TargetMetadata = {
      SupportLobs        = true
      FullLobMode        = false
      LimitedSizeLobMode = true
      LobMaxSize         = 32768
    }
    FullLoadSettings = {
      TargetTablePrepMode              = "DO_NOTHING"
      CreatePkAfterFullLoad            = false
      StopTaskCachedChangesApplied     = false
      StopTaskCachedChangesNotApplied  = false
      MaxFullLoadSubTasks              = 8
      TransactionConsistencyTimeout    = 600
      CommitRate                       = 50000
    }
    Logging = {
      EnableLogging = true
      LogComponents = [
        { Id = "SOURCE_UNLOAD", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "TARGET_LOAD",   Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "TASK_MANAGER",  Severity = "LOGGER_SEVERITY_DEFAULT" },
      ]
    }
  })

  table_mappings = jsonencode({
    rules = [

      # ── Selection Rule ────────────────────────────────────────────

      {
        rule-type   = "selection"
        rule-id     = "1"
        rule-name   = "sel-current-supplements"
        rule-action = "include"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
        }
      },

      # ── current_supplements → intake_supplements ──────────────────

      {
        rule-type   = "transformation"
        rule-id     = "101"
        rule-name   = "rename-table"
        rule-action = "rename"
        rule-target = "table"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
        }
        value = "intake_supplements"
      },
      {
        rule-type   = "transformation"
        rule-id     = "102"
        rule-name   = "rename-product-name"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "product_name"
        }
        value = "itk_product_name"
      },
      {
        rule-type   = "transformation"
        rule-id     = "103"
        rule-name   = "rename-serving-amount"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "serving_amount"
        }
        value = "itk_serving_amount"
      },
      {
        rule-type   = "transformation"
        rule-id     = "104"
        rule-name   = "rename-serving-per-day"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "serving_per_day"
        }
        value = "itk_serving_per_day"
      },
      {
        rule-type   = "transformation"
        rule-id     = "105"
        rule-name   = "rename-daily-total-amount"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "daily_total_amount"
        }
        value = "itk_daily_total_amount"
      },
      {
        rule-type   = "transformation"
        rule-id     = "106"
        rule-name   = "rename-total-quantity"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "total_quantity"
        }
        value = "itk_total_quantity"
      },
      {
        rule-type   = "transformation"
        rule-id     = "107"
        rule-name   = "rename-purchased-dt"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "purchased_dt"
        }
        value = "itk_purchased_dt"
      },
      {
        rule-type   = "transformation"
        rule-id     = "108"
        rule-name   = "rename-estimated-end-dt"
        rule-action = "rename"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "estimated_end_dt"
        }
        value = "itk_estimated_end_dt"
      },
      # intake_supplements에 없는 컬럼 제거
      {
        rule-type   = "transformation"
        rule-id     = "109"
        rule-name   = "remove-ingredients"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "ingredients"
        }
      },
      {
        rule-type   = "transformation"
        rule-id     = "110"
        rule-name   = "remove-start-dt"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "start_dt"
        }
      },
      {
        rule-type   = "transformation"
        rule-id     = "111"
        rule-name   = "remove-end-dt"
        rule-action = "remove-column"
        rule-target = "column"
        object-locator = {
          schema-name = "public"
          table-name  = "current_supplements"
          column-name = "end_dt"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-users-to-history"
  }
}

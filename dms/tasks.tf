# ============================================================
# DMS Replication Tasks
# 스키마 기준:
#   user.sql    → source (users DB)
#   analysis.sql → target (analysis DB)
#   chatbot.sql  → target (chatbot DB)
#   history.sql  → target (history DB)
# ============================================================

locals {
  task_settings = jsonencode({
    TargetMetadata = {
      SupportLobs        = true
      FullLobMode        = false
      LimitedSizeLobMode = true
      LobMaxSize         = 32768
    }
    FullLoadSettings = {
      TargetTablePrepMode             = "DO_NOTHING"
      CreatePkAfterFullLoad           = false
      StopTaskCachedChangesApplied    = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks             = 8
      TransactionConsistencyTimeout   = 600
      CommitRate                      = 50000
    }
    Logging = {
      EnableLogging = true
      LogComponents = [
        { Id = "SOURCE_UNLOAD", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "SOURCE_CAPTURE", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TARGET_LOAD", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TARGET_APPLY", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TASK_MANAGER", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TABLES_MANAGER", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "METADATA_MANAGER", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "COMMON", Severity = "LOGGER_SEVERITY_DEFAULT" },
      ]
    }
  })

  # staging 태스크용 (DO_NOTHING: 기존 데이터 보존)
  task_settings_staging = jsonencode({
    TargetMetadata = {
      SupportLobs        = true
      FullLobMode        = false
      LimitedSizeLobMode = true
      LobMaxSize         = 32768
    }
    FullLoadSettings = {
      TargetTablePrepMode             = "DO_NOTHING"
      CreatePkAfterFullLoad           = false
      StopTaskCachedChangesApplied    = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks             = 8
      TransactionConsistencyTimeout   = 600
      CommitRate                      = 50000
    }
    Logging = {
      EnableLogging = true
      LogComponents = [
        { Id = "SOURCE_UNLOAD", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "SOURCE_CAPTURE", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TARGET_LOAD", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TARGET_APPLY", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TASK_MANAGER", Severity = "LOGGER_SEVERITY_DETAILED_DEBUG" },
        { Id = "TABLES_MANAGER", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "METADATA_MANAGER", Severity = "LOGGER_SEVERITY_DEFAULT" },
        { Id = "COMMON", Severity = "LOGGER_SEVERITY_DEFAULT" },
      ]
    }
  })
}

# ============================================================
# Task 1: users → analysis
# user_profile        → analysis_userdata
#   - profile_id 제거 (analysis_userdata에 없음)
#   - name, phone 제거 (PII)
#   - birth_dt→ans_birth_dt, gender→ans_gender, height→ans_height
#   - weight→ans_weight, allergies→ans_allergies, chron_diseases→ans_chron_diseases
#   - cognito_id를 target PK로 명시 (source PK=profile_id와 불일치 해소)
# current_supplements → analysis_supplements
#   - current_id→ans_current_id, product_name→ans_product_name
#   - serving_amount→ans_serving_amount, serving_per_day→ans_serving_per_day
#   - daily_total_amount→ans_daily_total_amount, is_active→ans_is_active
#   - ingredients→ans_ingredients
#   - total_quantity, purchased_dt, estimated_end_dt, start_dt, end_dt 제거
# current_ingredients → anaysis_current_ingredients (스키마 오타 그대로)
#   - ingredient_id→ans_ingredient_id, current_id→ans_current_id
#   - ingredient_name→ans_ingredient_name, nutrient_amount→ans_nutrient_amount
# ============================================================

resource "aws_dms_replication_task" "user_to_analysis" {
  replication_task_id      = "${local.name_prefix}-user-to-analysis"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_users.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_analysis.endpoint_arn
  migration_type           = var.migration_type
  start_replication_task   = true

  replication_task_settings = local.task_settings

  table_mappings = jsonencode({
    rules = [
      # ── Selection ──────────────────────────────────────────────
      { rule-type   = "selection", rule-id = "1", rule-name = "sel-user-profile",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "user_profile" } },
      { rule-type   = "selection", rule-id = "2", rule-name = "sel-current-supplements",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "current_supplements" } },
      { rule-type   = "selection", rule-id = "3", rule-name = "sel-current-ingredients",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "current_ingredients" } },

      # ── user_profile → analysis_userdata ───────────────────────
      { rule-type      = "transformation", rule-id = "101", rule-name = "rename-tbl-user-profile",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "user_profile" },
      value = "analysis_userdata" },
      { rule-type      = "transformation", rule-id = "102", rule-name = "rename-birth-dt",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "birth_dt" },
      value = "ans_birth_dt" },
      { rule-type      = "transformation", rule-id = "103", rule-name = "rename-gender",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "gender" },
      value = "ans_gender" },
      { rule-type      = "transformation", rule-id = "104", rule-name = "rename-height",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "height" },
      value = "ans_height" },
      { rule-type      = "transformation", rule-id = "105", rule-name = "rename-weight",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "weight" },
      value = "ans_weight" },
      { rule-type      = "transformation", rule-id = "106", rule-name = "rename-allergies",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "allergies" },
      value = "ans_allergies" },
      { rule-type      = "transformation", rule-id = "107", rule-name = "rename-chron-diseases",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "chron_diseases" },
      value = "ans_chron_diseases" },
      { rule-type   = "transformation", rule-id = "108", rule-name = "remove-profile-id",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "user_profile", column-name = "profile_id" } },
      { rule-type   = "transformation", rule-id = "109", rule-name = "remove-name",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "user_profile", column-name = "name" } },
      { rule-type   = "transformation", rule-id = "110", rule-name = "remove-phone",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "user_profile", column-name = "phone" } },
      # CDC UPDATE/DELETE: source PK(profile_id) ≠ target PK(cognito_id) 불일치 해소
      { rule-type      = "transformation", rule-id = "111", rule-name = "set-pk-cognito-id",
        rule-action    = "define-primary-key", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "user_profile" },
      primary-key-def = { name = "analysis_userdata_pk", columns = ["cognito_id"] } },

      # ── current_supplements → analysis_supplements ─────────────
      { rule-type      = "transformation", rule-id = "201", rule-name = "rename-tbl-supplements",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "current_supplements" },
      value = "analysis_supplements" },
      { rule-type      = "transformation", rule-id = "202", rule-name = "rename-current-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "current_id" },
      value = "ans_current_id" },
      { rule-type      = "transformation", rule-id = "203", rule-name = "rename-product-name",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "product_name" },
      value = "ans_product_name" },
      { rule-type      = "transformation", rule-id = "204", rule-name = "rename-serving-amount",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "serving_amount" },
      value = "ans_serving_amount" },
      { rule-type      = "transformation", rule-id = "205", rule-name = "rename-serving-per-day",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "serving_per_day" },
      value = "ans_serving_per_day" },
      { rule-type      = "transformation", rule-id = "206", rule-name = "rename-daily-total",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "daily_total_amount" },
      value = "ans_daily_total_amount" },
      { rule-type      = "transformation", rule-id = "207", rule-name = "rename-is-active",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "is_active" },
      value = "ans_is_active" },
      { rule-type      = "transformation", rule-id = "208", rule-name = "rename-ingredients",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "ingredients" },
      value = "ans_ingredients" },
      { rule-type   = "transformation", rule-id = "209", rule-name = "remove-total-quantity",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "total_quantity" } },
      { rule-type   = "transformation", rule-id = "210", rule-name = "remove-purchased-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "purchased_dt" } },
      { rule-type   = "transformation", rule-id = "211", rule-name = "remove-estimated-end-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "estimated_end_dt" } },
      { rule-type   = "transformation", rule-id = "212", rule-name = "remove-start-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "start_dt" } },
      { rule-type   = "transformation", rule-id = "213", rule-name = "remove-end-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "end_dt" } },

      # ── current_ingredients → anaysis_current_ingredients (스키마 오타 그대로) ──
      { rule-type      = "transformation", rule-id = "301", rule-name = "rename-tbl-ingredients",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "current_ingredients" },
      value = "anaysis_current_ingredients" },
      { rule-type      = "transformation", rule-id = "302", rule-name = "rename-ingredient-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_ingredients", column-name = "ingredient_id" },
      value = "ans_ingredient_id" },
      { rule-type      = "transformation", rule-id = "303", rule-name = "rename-ci-current-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_ingredients", column-name = "current_id" },
      value = "ans_current_id" },
      { rule-type      = "transformation", rule-id = "304", rule-name = "rename-ingredient-name",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_ingredients", column-name = "ingredient_name" },
      value = "ans_ingredient_name" },
      { rule-type      = "transformation", rule-id = "305", rule-name = "rename-nutrient-amount",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_ingredients", column-name = "nutrient_amount" },
      value = "ans_nutrient_amount" },
    ]
  })

  tags = { Name = "${local.name_prefix}-user-to-analysis" }
}

# ============================================================
# Task 2: users → analysis (staging)
# user_condition_snapshots → analysis_condition_staging
#   - snapshot_id 유지 (staging PK)
#   - cognito_id 유지
#   - status → condition_status
# PostgreSQL 트리거가 staging INSERT 시 analysis_userdata.ans_current_conditions 업데이트
# ============================================================

resource "aws_dms_replication_task" "user_condition_to_analysis" {
  replication_task_id      = "${local.name_prefix}-user-condition-to-analysis"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_users.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_analysis.endpoint_arn
  migration_type           = var.migration_type
  start_replication_task   = true

  replication_task_settings = local.task_settings_staging

  table_mappings = jsonencode({
    rules = [
      { rule-type   = "selection", rule-id = "1", rule-name = "sel-user-condition-snapshots",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "user_condition_snapshots" } },
      { rule-type      = "transformation", rule-id = "101", rule-name = "rename-tbl-to-staging",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "user_condition_snapshots" },
      value = "analysis_condition_staging" },
      { rule-type      = "transformation", rule-id = "102", rule-name = "rename-status",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_condition_snapshots", column-name = "status" },
      value = "condition_status" },
    ]
  })

  tags = { Name = "${local.name_prefix}-user-condition-to-analysis" }
}

# ============================================================
# Task 3: users → history
# current_supplements → intake_supplements
#   - current_id 유지 (PK, history.sql에서 current_id가 PK)
#   - product_name→itk_product_name, serving_amount→itk_serving_amount
#   - serving_per_day→itk_serving_per_day, daily_total_amount→itk_daily_total_amount
#   - total_quantity→itk_total_quantity, purchased_dt→itk_purchased_dt
#   - estimated_end_dt→itk_estimated_end_dt
#   - ingredients, start_dt, end_dt 제거 (intake_supplements에 없음)
# ============================================================

resource "aws_dms_replication_task" "users_to_history" {
  replication_task_id      = "${local.name_prefix}-users-to-history"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_users.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_history.endpoint_arn
  migration_type           = var.migration_type
  start_replication_task   = true

  replication_task_settings = local.task_settings

  table_mappings = jsonencode({
    rules = [
      { rule-type   = "selection", rule-id = "1", rule-name = "sel-current-supplements",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "current_supplements" } },

      { rule-type      = "transformation", rule-id = "101", rule-name = "rename-tbl-to-intake",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "current_supplements" },
      value = "intake_supplements" },
      { rule-type      = "transformation", rule-id = "102", rule-name = "rename-product-name",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "product_name" },
      value = "itk_product_name" },
      { rule-type      = "transformation", rule-id = "103", rule-name = "rename-serving-amount",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "serving_amount" },
      value = "itk_serving_amount" },
      { rule-type      = "transformation", rule-id = "104", rule-name = "rename-serving-per-day",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "serving_per_day" },
      value = "itk_serving_per_day" },
      { rule-type      = "transformation", rule-id = "105", rule-name = "rename-daily-total",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "daily_total_amount" },
      value = "itk_daily_total_amount" },
      { rule-type      = "transformation", rule-id = "106", rule-name = "rename-total-quantity",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "total_quantity" },
      value = "itk_total_quantity" },
      { rule-type      = "transformation", rule-id = "107", rule-name = "rename-purchased-dt",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "purchased_dt" },
      value = "itk_purchased_dt" },
      { rule-type      = "transformation", rule-id = "108", rule-name = "rename-estimated-end-dt",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "estimated_end_dt" },
      value = "itk_estimated_end_dt" },
      { rule-type   = "transformation", rule-id = "109", rule-name = "remove-ingredients",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "ingredients" } },
      { rule-type   = "transformation", rule-id = "110", rule-name = "remove-start-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "start_dt" } },
      { rule-type   = "transformation", rule-id = "111", rule-name = "remove-end-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "end_dt" } },
    ]
  })

  tags = { Name = "${local.name_prefix}-users-to-history" }
}

# ============================================================
# Task 4: users → chatbot
# user_profile → chatbot_userdata
#   - profile_id, name, phone 제거
#   - birth_dt→chat_birth_dt, gender→chat_gender, height→chat_height
#   - weight→chat_weight, allergies→chat_allergies, chron_diseases→chat_chron_diseases
#   - cognito_id를 target PK로 명시
# current_supplements → chatbot_supplements
#   - current_id→chat_current_id, product_name→chat_product_name
#   - serving_amount→chat_serving_amount, serving_per_day→chat_serving_per_day
#   - daily_total_amount→chat_daily_total_amount, is_active→chat_is_active
#   - ingredients→chat_ingredients
#   - total_quantity, purchased_dt, estimated_end_dt, start_dt, end_dt 제거
# current_ingredients → chatbot_current_ingredients
#   - ingredient_id→chat_ingredient_id, current_id→chat_current_id
#   - ingredient_name→chat_ingredient_name, nutrient_amount→chat_nutrient_amount
# ============================================================

resource "aws_dms_replication_task" "users_to_chatbot" {
  replication_task_id      = "${local.name_prefix}-users-to-chatbot"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_users.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_chatbot.endpoint_arn
  migration_type           = var.migration_type
  start_replication_task   = true

  replication_task_settings = local.task_settings

  table_mappings = jsonencode({
    rules = [
      { rule-type   = "selection", rule-id = "1", rule-name = "sel-user-profile",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "user_profile" } },
      { rule-type   = "selection", rule-id = "2", rule-name = "sel-current-supplements",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "current_supplements" } },
      { rule-type   = "selection", rule-id = "3", rule-name = "sel-current-ingredients",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "current_ingredients" } },

      # ── user_profile → chatbot_userdata ────────────────────────
      { rule-type      = "transformation", rule-id = "101", rule-name = "rename-tbl-user-profile",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "user_profile" },
      value = "chatbot_userdata" },
      { rule-type      = "transformation", rule-id = "102", rule-name = "rename-birth-dt",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "birth_dt" },
      value = "chat_birth_dt" },
      { rule-type      = "transformation", rule-id = "103", rule-name = "rename-gender",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "gender" },
      value = "chat_gender" },
      { rule-type      = "transformation", rule-id = "104", rule-name = "rename-height",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "height" },
      value = "chat_height" },
      { rule-type      = "transformation", rule-id = "105", rule-name = "rename-weight",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "weight" },
      value = "chat_weight" },
      { rule-type      = "transformation", rule-id = "106", rule-name = "rename-allergies",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "allergies" },
      value = "chat_allergies" },
      { rule-type      = "transformation", rule-id = "107", rule-name = "rename-chron-diseases",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_profile", column-name = "chron_diseases" },
      value = "chat_chron_diseases" },
      { rule-type   = "transformation", rule-id = "108", rule-name = "remove-profile-id",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "user_profile", column-name = "profile_id" } },
      { rule-type   = "transformation", rule-id = "109", rule-name = "remove-name",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "user_profile", column-name = "name" } },
      { rule-type   = "transformation", rule-id = "110", rule-name = "remove-phone",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "user_profile", column-name = "phone" } },
      { rule-type      = "transformation", rule-id = "111", rule-name = "set-pk-cognito-id",
        rule-action    = "define-primary-key", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "user_profile" },
      primary-key-def = { name = "chatbot_userdata_pk", columns = ["cognito_id"] } },

      # ── current_supplements → chatbot_supplements ──────────────
      { rule-type      = "transformation", rule-id = "201", rule-name = "rename-tbl-supplements",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "current_supplements" },
      value = "chatbot_supplements" },
      { rule-type      = "transformation", rule-id = "202", rule-name = "rename-current-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "current_id" },
      value = "chat_current_id" },
      { rule-type      = "transformation", rule-id = "203", rule-name = "rename-product-name",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "product_name" },
      value = "chat_product_name" },
      { rule-type      = "transformation", rule-id = "204", rule-name = "rename-serving-amount",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "serving_amount" },
      value = "chat_serving_amount" },
      { rule-type      = "transformation", rule-id = "205", rule-name = "rename-serving-per-day",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "serving_per_day" },
      value = "chat_serving_per_day" },
      { rule-type      = "transformation", rule-id = "206", rule-name = "rename-daily-total",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "daily_total_amount" },
      value = "chat_daily_total_amount" },
      { rule-type      = "transformation", rule-id = "207", rule-name = "rename-is-active",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "is_active" },
      value = "chat_is_active" },
      { rule-type      = "transformation", rule-id = "208", rule-name = "rename-ingredients",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "ingredients" },
      value = "chat_ingredients" },
      { rule-type   = "transformation", rule-id = "209", rule-name = "remove-total-quantity",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "total_quantity" } },
      { rule-type   = "transformation", rule-id = "210", rule-name = "remove-purchased-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "purchased_dt" } },
      { rule-type   = "transformation", rule-id = "211", rule-name = "remove-estimated-end-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "estimated_end_dt" } },
      { rule-type   = "transformation", rule-id = "212", rule-name = "remove-start-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "start_dt" } },
      { rule-type   = "transformation", rule-id = "213", rule-name = "remove-end-dt",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "current_supplements", column-name = "end_dt" } },

      # ── current_ingredients → chatbot_current_ingredients ──────
      { rule-type      = "transformation", rule-id = "301", rule-name = "rename-tbl-ingredients",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "current_ingredients" },
      value = "chatbot_current_ingredients" },
      { rule-type      = "transformation", rule-id = "302", rule-name = "rename-ingredient-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_ingredients", column-name = "ingredient_id" },
      value = "chat_ingredient_id" },
      { rule-type      = "transformation", rule-id = "303", rule-name = "rename-ci-current-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_ingredients", column-name = "current_id" },
      value = "chat_current_id" },
      { rule-type      = "transformation", rule-id = "304", rule-name = "rename-ingredient-name",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_ingredients", column-name = "ingredient_name" },
      value = "chat_ingredient_name" },
      { rule-type      = "transformation", rule-id = "305", rule-name = "rename-nutrient-amount",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "current_ingredients", column-name = "nutrient_amount" },
      value = "chat_nutrient_amount" },
    ]
  })

  tags = { Name = "${local.name_prefix}-users-to-chatbot" }
}

# ============================================================
# Task 5: users → chatbot (staging)
# user_condition_snapshots → chatbot_condition_staging
#   - status → condition_status
# PostgreSQL 트리거가 chatbot_userdata.chat_current_conditions 업데이트
# ============================================================

resource "aws_dms_replication_task" "user_condition_to_chatbot" {
  replication_task_id      = "${local.name_prefix}-user-condition-to-chatbot"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_users.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_chatbot.endpoint_arn
  migration_type           = var.migration_type
  start_replication_task   = true

  replication_task_settings = local.task_settings_staging

  table_mappings = jsonencode({
    rules = [
      { rule-type   = "selection", rule-id = "1", rule-name = "sel-user-condition-snapshots",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "user_condition_snapshots" } },
      { rule-type      = "transformation", rule-id = "101", rule-name = "rename-tbl-to-staging",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "user_condition_snapshots" },
      value = "chatbot_condition_staging" },
      { rule-type      = "transformation", rule-id = "102", rule-name = "rename-status",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "user_condition_snapshots", column-name = "status" },
      value = "condition_status" },
    ]
  })

  tags = { Name = "${local.name_prefix}-user-condition-to-chatbot" }
}

# ============================================================
# Task 6: analysis → chatbot
# analysis_result → chatbot_analysis_result
#   - result_id→chat_result_id, summary→chat_summary
# nutrient_gap → chatbot_nutrient_gap
#   - gap_id→chat_gap_id, result_id→chat_result_id
#   - current_amount→chat_current_amount, gap_amount→chat_gap_amount, unit→chat_unit
#   - nutrient_id 제거 (chatbot_nutrient_gap에 없음)
#   - cognito_id 제거 (chatbot_nutrient_gap에 없음)
# recommendations → chatbot_recommendations
#   - rec_id→chat_rec_id, rank→chat_rank, recommend_serving→chat_recommend_serving
#   - result_id, product_id, cognito_id 제거 (chatbot_recommendations에 없음)
#   - chatbot_recommendations.chat_gap_id는 chatbot_nutrient_gap 참조 (DMS 미지원, 앱 레벨 처리)
# ============================================================

resource "aws_dms_replication_task" "analysis_to_chatbot" {
  replication_task_id      = "${local.name_prefix}-analysis-to-chatbot"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_analysis.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_chatbot.endpoint_arn
  migration_type           = var.migration_type
  start_replication_task   = true

  replication_task_settings = local.task_settings

  table_mappings = jsonencode({
    rules = [
      { rule-type   = "selection", rule-id = "1", rule-name = "sel-analysis-result",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "analysis_result" } },
      { rule-type   = "selection", rule-id = "2", rule-name = "sel-nutrient-gap",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "nutrient_gap" } },
      { rule-type   = "selection", rule-id = "3", rule-name = "sel-recommendations",
        rule-action = "include",
      object-locator = { schema-name = "public", table-name = "recommendations" } },

      # ── analysis_result → chatbot_analysis_result ──────────────
      { rule-type      = "transformation", rule-id = "101", rule-name = "rename-tbl-analysis-result",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "analysis_result" },
      value = "chatbot_analysis_result" },
      { rule-type      = "transformation", rule-id = "102", rule-name = "rename-result-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "analysis_result", column-name = "result_id" },
      value = "chat_result_id" },
      { rule-type      = "transformation", rule-id = "103", rule-name = "rename-summary",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "analysis_result", column-name = "summary" },
      value = "chat_summary" },

      # ── nutrient_gap → chatbot_nutrient_gap ────────────────────
      { rule-type      = "transformation", rule-id = "201", rule-name = "rename-tbl-nutrient-gap",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "nutrient_gap" },
      value = "chatbot_nutrient_gap" },
      { rule-type      = "transformation", rule-id = "202", rule-name = "rename-gap-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "nutrient_gap", column-name = "gap_id" },
      value = "chat_gap_id" },
      { rule-type      = "transformation", rule-id = "203", rule-name = "rename-ng-result-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "nutrient_gap", column-name = "result_id" },
      value = "chat_result_id" },
      { rule-type      = "transformation", rule-id = "204", rule-name = "rename-current-amount",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "nutrient_gap", column-name = "current_amount" },
      value = "chat_current_amount" },
      { rule-type      = "transformation", rule-id = "205", rule-name = "rename-gap-amount",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "nutrient_gap", column-name = "gap_amount" },
      value = "chat_gap_amount" },
      { rule-type      = "transformation", rule-id = "206", rule-name = "rename-unit",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "nutrient_gap", column-name = "unit" },
      value = "chat_unit" },
      { rule-type   = "transformation", rule-id = "207", rule-name = "remove-nutrient-id",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "nutrient_gap", column-name = "nutrient_id" } },
      { rule-type   = "transformation", rule-id = "208", rule-name = "remove-ng-cognito-id",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "nutrient_gap", column-name = "cognito_id" } },

      # ── recommendations → chatbot_recommendations ──────────────
      { rule-type      = "transformation", rule-id = "301", rule-name = "rename-tbl-recommendations",
        rule-action    = "rename", rule-target = "table",
        object-locator = { schema-name = "public", table-name = "recommendations" },
      value = "chatbot_recommendations" },
      { rule-type      = "transformation", rule-id = "302", rule-name = "rename-rec-id",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "recommendations", column-name = "rec_id" },
      value = "chat_rec_id" },
      { rule-type      = "transformation", rule-id = "303", rule-name = "rename-recommend-serving",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "recommendations", column-name = "recommend_serving" },
      value = "chat_recommend_serving" },
      { rule-type      = "transformation", rule-id = "304", rule-name = "rename-rank",
        rule-action    = "rename", rule-target = "column",
        object-locator = { schema-name = "public", table-name = "recommendations", column-name = "rank" },
      value = "chat_rank" },
      { rule-type   = "transformation", rule-id = "305", rule-name = "remove-result-id",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "recommendations", column-name = "result_id" } },
      { rule-type   = "transformation", rule-id = "306", rule-name = "remove-product-id",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "recommendations", column-name = "product_id" } },
      { rule-type   = "transformation", rule-id = "307", rule-name = "remove-rec-cognito-id",
        rule-action = "remove-column", rule-target = "column",
      object-locator = { schema-name = "public", table-name = "recommendations", column-name = "cognito_id" } },
    ]
  })

  tags = { Name = "${local.name_prefix}-analysis-to-chatbot" }
}

# ============================================================
# 시나리오 04: Aurora 인스턴스 재부팅
# ============================================================
# 목적: DB 인스턴스 재부팅 시 ECS 서비스의 연결 풀 복구력 검증
#       (페일오버보다 가벼운 장애 - Reader 인스턴스 대상)
#
# 대상: analysis-cluster Reader 인스턴스
#       (AI 분석 서비스 DB - 재부팅 중 쿼리 실패 허용 범위 확인)
# 액션: Reader 인스턴스 재부팅 (약 1-2분 다운타임)
# 기대 결과:
#   - Writer 인스턴스는 정상 유지 (쓰기 트래픽 영향 없음)
#   - 앱의 DB 연결 풀이 재부팅 후 자동 재연결
#   - 재부팅 중 읽기 쿼리 실패 → 앱 레벨 retry 동작 확인
# ============================================================

resource "aws_fis_experiment_template" "aurora_reboot" {
  description = "[시나리오 04] Aurora Reader 인스턴스 재부팅 - 연결 풀 복구력 검증"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  # ── 액션: analysis-cluster Reader 재부팅 ──────────────────
  action {
    name        = "reboot-analysis-reader"
    action_id   = "aws:rds:reboot-db-instances"
    description = "analysis-cluster Reader 인스턴스 재부팅"

    target {
      key   = "DBInstances"
      value = "aurora-analysis-reader"
    }
  }

  # ── 타겟: analysis-cluster Reader 인스턴스 ────────────────
  target {
    name           = "aurora-analysis-reader"
    resource_type  = "aws:rds:db"
    selection_mode = "ALL"

    resource_tag {
      key   = "Role"
      value = "Reader"
    }

    resource_tag {
      key   = "Name"
      value = "cdci-prd-analysis-cluster-ro"
    }
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-AURORA-REBOOT"
    Scenario = "04-aurora-reboot"
  }
}

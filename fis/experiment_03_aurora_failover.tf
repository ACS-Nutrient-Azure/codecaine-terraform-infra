# ============================================================
# 시나리오 03: Aurora 클러스터 강제 페일오버
# ============================================================
# 목적: Aurora Writer → Reader 자동 승격 및
#       ECS 서비스의 DB 재연결 복구력 검증
#
# 대상: users-cluster (핵심 서비스 DB)
# 액션: Aurora 클러스터 페일오버 (Writer 인스턴스 교체)
# 기대 결과:
#   - Aurora 페일오버 완료 < 30초
#   - ECS 서비스가 새 Writer 엔드포인트로 자동 재연결
#   - Secrets Manager 엔드포인트는 클러스터 DNS이므로 앱 변경 불필요
#   - CloudWatch DatabaseConnections 메트릭 일시 0 후 복구
#
# 주의: prd 환경에서는 deletion_protection = true이므로
#       페일오버만 수행 (클러스터 삭제 아님)
# ============================================================

resource "aws_fis_experiment_template" "aurora_failover" {
  description = "[시나리오 03] Aurora 강제 페일오버 - Writer/Reader 전환 및 앱 재연결 검증"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  # ── 액션 1: users-cluster 페일오버 ────────────────────────
  action {
    name        = "failover-users-cluster"
    action_id   = "aws:rds:failover-db-cluster"
    description = "users Aurora 클러스터 Writer → Reader 강제 전환"

    target {
      key   = "Clusters"
      value = "aurora-users-cluster"
    }
  }

  # ── 액션 2: history-cluster 페일오버 (3분 후) ─────────────
  # users 복구 확인 후 순차 실행 (동시 페일오버 방지)
  # startDelay는 aws:rds:failover-db-cluster에서 미지원 → start_after로 순서 제어
  action {
    name        = "failover-history-cluster"
    action_id   = "aws:rds:failover-db-cluster"
    description = "history Aurora 클러스터 Writer → Reader 강제 전환 (users 완료 후)"

    start_after = ["failover-users-cluster"]

    target {
      key   = "Clusters"
      value = "aurora-history-cluster"
    }
  }

  # ── 타겟: users-cluster ────────────────────────────────────
  target {
    name           = "aurora-users-cluster"
    resource_type  = "aws:rds:cluster"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "cdci-prd-users-cluster"
    }
  }

  # ── 타겟: history-cluster ──────────────────────────────────
  target {
    name           = "aurora-history-cluster"
    resource_type  = "aws:rds:cluster"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "cdci-prd-history-cluster"
    }
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-AURORA-FAILOVER"
    Scenario = "03-aurora-failover"
  }
}

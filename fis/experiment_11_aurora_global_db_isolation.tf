# ============================================================
# 시나리오 11: Aurora Global DB Primary 격리 (Aurora 레이어 DR 트리거)
# ============================================================
# 목적: Aurora Global DB Primary(서울) 클러스터 연결 차단으로
#       DatabaseConnections=0 알람을 트리거하여
#       Aurora 레이어 장애 감지 → DR Composite Alarm 발화 검증
#
# 구성:
#   - Aurora Global Cluster: users, history, analysis, chatbot (4개)
#   - Primary: ap-northeast-2 (서울) / Secondary: ap-northeast-1 (도쿄)
#   - DB Subnet: 10.0.21.0/24 (2a), 10.0.22.0/24 (2c)
#
# 액션 순서:
#   1. DB Subnet 2a 네트워크 완전 차단 (ingress+egress)
#   2. 30초 후: DB Subnet 2c 네트워크 완전 차단
#      → 모든 Aurora 클러스터 연결 불가 (DatabaseConnections=0)
#   3. 2분 대기 → aurora_connections 알람 2개 이상 ALARM 전환
#      → aurora_layer_failure Composite Alarm ALARM
#
# DR 트리거 조건 충족 경로:
#   aurora_layer_failure ALARM + agentcore_health ALARM
#   (NAT 차단으로 Bedrock 접근 불가 → AgentCore 헬스체크 실패 동반)
#
# 기대 결과:
#   - DatabaseConnections=0 알람 4개 클러스터 중 2개 이상 ALARM
#   - aurora_layer_failure Composite Alarm ALARM 전환
#   - DR Composite Alarm(cdci-prd-DR-TRIGGER) ALARM 전환
#   - EventBridge → Step Functions DR Orchestrator 자동 실행
#   - Aurora Global DB Failover: 도쿄 Secondary → Primary 승격
#
# ⚠️  주의:
#   - DB Subnet 차단은 FIS aws:network:disrupt-connectivity 사용
#     (Global DB 직접 조작 미지원으로 네트워크 격리 방식 채택)
#   - 실험 종료 시 NACL 자동 복구되나 Aurora 재연결에 30~60초 소요
#   - DR Composite Alarm이 ALARM 전환되면 실제 Failover가 실행됨
#     → 반드시 DR 인프라(dr/ 모듈) 배포 완료 후 실행
#   - 실험 후 Aurora Global DB 재동기화(Resync) 수동 수행 필요
# ============================================================

resource "aws_fis_experiment_template" "aurora_global_db_isolation" {
  description = "[시나리오 11] Aurora Global DB Primary 격리 - DB Subnet 차단으로 Aurora 레이어 DR 트리거 검증"
  role_arn    = aws_iam_role.fis.arn

  # DR Composite Alarm 자체가 목표이므로 stop_condition은 none
  # (알람 발화 확인 후 수동 종료 또는 duration 만료로 복구)
  stop_condition {
    source = "none"
  }

  # ── 액션 1: DB Subnet 2a 완전 차단 ───────────────────────
  # Aurora Writer/Reader 인스턴스가 위치한 2a 서브넷 격리
  action {
    name        = "isolate-db-subnet-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "DB Subnet 2a 완전 차단 (Aurora Primary 연결 불가)"

    parameter {
      key   = "duration"
      value = "PT15M"
    }

    parameter {
      key   = "scope"
      value = "all" # ingress + egress 모두 차단
    }

    target {
      key   = "Subnets"
      value = "aurora-db-subnet-2a"
    }
  }

  # ── 액션 2: DB Subnet 2c 완전 차단 (30초 후) ─────────────
  # 2a 차단 후 Aurora가 2c로 재연결 시도하는 것도 차단
  # → 모든 클러스터 DatabaseConnections=0 유도
  action {
    name        = "isolate-db-subnet-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "DB Subnet 2c 완전 차단 (Aurora 전체 연결 불가)"

    start_after = ["isolate-db-subnet-2a"]

    parameter {
      key   = "duration"
      value = "PT14M" # 2a보다 30초 늦게 시작하므로 총 실험 시간 맞춤
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "aurora-db-subnet-2c"
    }
  }

  # ── 타겟: Private DB Subnet 2a ────────────────────────────
  target {
    name           = "aurora-db-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-DB-2A"
    }
  }

  # ── 타겟: Private DB Subnet 2c ────────────────────────────
  target {
    name           = "aurora-db-subnet-2c"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-DB-2C"
    }
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-AURORA-GLOBAL-ISOLATION"
    Scenario = "11-aurora-global-db-isolation"
  }
}

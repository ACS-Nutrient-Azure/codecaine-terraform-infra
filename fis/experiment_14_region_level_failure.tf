# ============================================================
# 시나리오 14: 리전 수준 장애 시뮬레이션 (Region-Level Failure)
# ============================================================
# 목적: 서울 리전 전체 장애를 모사하는 복합 시나리오
#       Public Subnet + DB Subnet 동시 차단으로
#       ECS 레이어 + Aurora 레이어 동시 장애 → DR Composite Alarm 트리거
#       Route53 Failover Record 자동 전환 검증
#
# 구성:
#   - Public Subnet:     10.0.1.0/24 (2a), 10.0.2.0/24 (2c)
#     → ALB가 위치, 외부 트래픽 수신 담당
#   - Private App Subnet: 10.0.11.0/24 (2a), 10.0.12.0/24 (2c)
#     → ECS Fargate 태스크 실행 위치
#   - Private DB Subnet:  10.0.21.0/24 (2a), 10.0.22.0/24 (2c)
#     → Aurora 클러스터 인스턴스 위치
#
# 리전 장애 모사 전략:
#   - Public Subnet 차단: ALB → ECS 통신 차단 (외부 트래픽 수신 불가)
#   - DB Subnet 차단: Aurora 클러스터 연결 불가 (DatabaseConnections=0)
#   - 동시 차단으로 ECS 레이어 + Aurora 레이어 동시 ALARM 유도
#
# 액션 순서:
#   T+0:00  Public Subnet 2a 완전 차단 (ALB → ECS 2a 통신 불가)
#   T+0:00  DB Subnet 2a 완전 차단 (Aurora 2a 연결 불가) [동시]
#   T+0:30  Public Subnet 2c 완전 차단 (ALB → ECS 2c 통신 불가)
#   T+0:30  DB Subnet 2c 완전 차단 (Aurora 2c 연결 불가) [동시]
#   T+1:30  ALB UnhealthyHostCount 알람 ALARM (3회 연속 × 30초)
#   T+2:00  DatabaseConnections=0 알람 ALARM (2회 연속 × 60초)
#   T+2:00  ecs_layer_failure + aurora_layer_failure 동시 ALARM
#   T+2:00  DR Composite Alarm(cdci-prd-DR-TRIGGER) ALARM 전환
#   T+2:30  EventBridge → Step Functions DR Orchestrator 실행
#
# 기대 결과:
#   - ECS 레이어 장애: users + history + chatbot UnhealthyHostCount ≥ 1
#   - Aurora 레이어 장애: 4개 클러스터 중 2개 이상 DatabaseConnections=0
#   - DR Composite Alarm ALARM 전환 (ECS + Aurora 동시 장애)
#   - Step Functions: Aurora Global DB Failover → 도쿄 Secondary 승격
#   - Step Functions: DR ECS 서비스 활성화 (desired_count 0 → 2)
#   - Step Functions: AgentCore Runtime 프로비저닝 (도쿄)
#   - Route53 Failover Record: 서울 ALB → 도쿄 ALB 자동 전환
#   - 전체 DR 완료 시간 측정 (목표: 15분 이내)
#
# ⚠️  주의:
#   - 이 시나리오는 실제 DR을 트리거합니다 (가장 강력한 시나리오)
#   - DR 인프라(dr/ 모듈) 완전 배포 후에만 실행
#   - 실험 종료 후 수동 복구 절차:
#     1. Aurora Global DB 재동기화 (서울 → 도쿄 방향 역전)
#     2. Route53 Failover Record 서울로 복구
#     3. DR ECS 서비스 desired_count 0으로 복구
#     4. AgentCore Runtime 삭제 (DR 환경)
#   - stop_condition = none (DR 트리거 자체가 목표이므로)
#   - 실험 전 팀 전체 공지 및 온콜 엔지니어 대기 필수
# ============================================================

resource "aws_fis_experiment_template" "region_level_failure" {
  description = "[시나리오 14] 리전 수준 장애 시뮬레이션 - Public+DB Subnet 동시 차단으로 전체 DR 파이프라인 검증"
  role_arn    = aws_iam_role.fis.arn

  # DR 트리거 자체가 목표이므로 stop_condition = none
  # 실험은 duration 만료(20분) 후 NACL 자동 복구
  stop_condition {
    source = "none"
  }

  # ── 액션 1: Public Subnet 2a 완전 차단 ───────────────────
  # ALB가 위치한 Public Subnet 차단 → ECS 태스크로의 트래픽 불가
  # → ALB 헬스체크 실패 → UnhealthyHostCount 증가
  action {
    name        = "block-public-subnet-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Public Subnet 2a 완전 차단 (ALB 외부 트래픽 수신 불가)"

    parameter {
      key   = "duration"
      value = "PT20M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "region-public-subnet-2a"
    }
  }

  # ── 액션 2: DB Subnet 2a 완전 차단 (동시) ────────────────
  # Aurora 클러스터 인스턴스 격리 → DatabaseConnections=0
  action {
    name        = "block-db-subnet-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "DB Subnet 2a 완전 차단 (Aurora Primary 연결 불가)"

    parameter {
      key   = "duration"
      value = "PT20M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "region-db-subnet-2a"
    }
  }

  # ── 액션 3: Public Subnet 2c 완전 차단 (30초 후) ─────────
  # 2a 차단 후 2c로 failover된 트래픽도 차단
  action {
    name        = "block-public-subnet-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Public Subnet 2c 완전 차단 (ALB 전체 외부 트래픽 불가)"

    start_after = ["block-public-subnet-2a", "block-db-subnet-2a"]

    parameter {
      key   = "duration"
      value = "PT19M" # 2a보다 30초 늦게 시작
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "region-public-subnet-2c"
    }
  }

  # ── 액션 4: DB Subnet 2c 완전 차단 (30초 후, 동시) ───────
  # Aurora 2c 인스턴스도 격리 → 전체 클러스터 연결 불가
  action {
    name        = "block-db-subnet-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "DB Subnet 2c 완전 차단 (Aurora 전체 연결 불가)"

    start_after = ["block-public-subnet-2a", "block-db-subnet-2a"]

    parameter {
      key   = "duration"
      value = "PT19M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "region-db-subnet-2c"
    }
  }

  # ── 타겟: Public Subnet 2a ────────────────────────────────
  target {
    name           = "region-public-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PUBLIC-2A"
    }
  }

  # ── 타겟: Public Subnet 2c ────────────────────────────────
  target {
    name           = "region-public-subnet-2c"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PUBLIC-2C"
    }
  }

  # ── 타겟: Private DB Subnet 2a ────────────────────────────
  target {
    name           = "region-db-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-DB-2A"
    }
  }

  # ── 타겟: Private DB Subnet 2c ────────────────────────────
  target {
    name           = "region-db-subnet-2c"
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
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-REGION-LEVEL-FAILURE"
    Scenario = "14-region-level-failure"
  }
}

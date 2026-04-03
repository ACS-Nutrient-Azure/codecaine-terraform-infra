# ============================================================
# 시나리오 12: AgentCore 레이어 장애 (NAT 차단 → Bedrock 접근 불가)
# ============================================================
# 목적: NAT Gateway egress 차단으로 Bedrock API 접근 불가 유도 →
#       AgentCore Health Check Lambda 실패 → agentcore_health 알람 ALARM →
#       Aurora 레이어 장애와 결합 시 DR Composite Alarm 트리거 검증
#
# 구성:
#   - AgentCore Health Check Lambda: 1분 주기 EventBridge Scheduled Rule
#   - 헬스체크 메트릭: AgentCoreHealthy (cdci/DR namespace)
#   - 알람 조건: Minimum < 1, 3회 연속 (3분) → ALARM
#   - Bedrock API: NAT Gateway 경유 (VPC Endpoint 없음)
#   - AgentCore Runtime: analysis, chatbot, summary 3개
#
# 액션 순서:
#   1. Private App Subnet 2a egress 차단 (NAT 경유 Bedrock 접근 불가)
#   2. 30초 후: Private App Subnet 2c egress 차단
#      → 모든 ECS 태스크의 Bedrock API 호출 실패
#      → AgentCore Health Check Lambda 실패 (Bedrock invoke 불가)
#   3. 3분 후: agentcore_health 알람 ALARM 전환 (3회 연속 실패)
#
# DR 트리거 조건 충족 경로 (단독으로는 DR 미트리거):
#   agentcore_health ALARM + aurora_layer_failure ALARM → DR 트리거
#   agentcore_health ALARM + ecs_layer_failure ALARM   → DR 트리거
#
# 기대 결과:
#   - Bedrock API 호출 실패 (ConnectionTimeout)
#   - AgentCoreHealthy 메트릭 0 발행 (3분 연속)
#   - agentcore_health CloudWatch Alarm ALARM 전환
#   - analysis/chatbot 서비스 AI 기능 저하 (fallback 응답)
#   - ECS 태스크 자체는 정상 (VPC 내부 통신 유지)
#   - ECR 이미지 pull 실패 (신규 태스크 기동 불가)
#   - Secrets Manager 신규 조회 실패 (캐시된 값은 유지)
#
# ⚠️  주의:
#   - 이 시나리오 단독으로는 DR이 트리거되지 않음
#   - DR 트리거 검증 시 시나리오 11(Aurora 격리)과 병행 실행 필요
#   - 실험 종료 후 AgentCore 알람 OK 전환까지 최대 3분 소요
#   - VPC Endpoint(S3, SSM, ECR)가 있는 경우 해당 서비스는 영향 없음
# ============================================================

resource "aws_fis_experiment_template" "agentcore_layer_failure" {
  description = "[시나리오 12] AgentCore 레이어 장애 - NAT 차단으로 Bedrock 접근 불가 → AgentCore 헬스체크 실패 검증"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = local.stop_condition_alarm_arn
  }

  # ── 액션 1: Private App Subnet 2a egress 차단 ────────────
  # NAT Gateway 경유 인터넷 트래픽 차단 (Bedrock, 외부 API)
  # VPC 내부 통신(ECS ↔ RDS, ECS ↔ Redis)은 유지
  action {
    name        = "block-egress-app-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Private App Subnet 2a egress 차단 (Bedrock API 접근 불가)"

    parameter {
      key   = "duration"
      value = "PT12M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "agentcore-app-subnet-2a"
    }
  }

  # ── 액션 2: Private App Subnet 2c egress 차단 (30초 후) ──
  # 2a 차단 후 2c로 failover된 태스크도 차단
  # → 전체 AgentCore Health Check Lambda Bedrock 호출 실패
  action {
    name        = "block-egress-app-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Private App Subnet 2c egress 차단 (Bedrock API 접근 불가)"

    start_after = ["block-egress-app-2a"]

    parameter {
      key   = "duration"
      value = "PT11M" # 2a보다 30초 늦게 시작
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "agentcore-app-subnet-2c"
    }
  }

  # ── 타겟: Private App Subnet 2a ───────────────────────────
  target {
    name           = "agentcore-app-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-APP-2A"
    }
  }

  # ── 타겟: Private App Subnet 2c ───────────────────────────
  target {
    name           = "agentcore-app-subnet-2c"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-APP-2C"
    }
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-AGENTCORE-LAYER-FAILURE"
    Scenario = "12-agentcore-layer-failure"
  }
}

# ============================================================
# 시나리오 13: 점진적 ECS 서비스 저하 (Gradual Degradation)
# ============================================================
# 목적: 즉시 종료가 아닌 CPU/메모리 부하 → 헬스체크 실패 →
#       ALB UnhealthyHostCount 증가 → ECS 레이어 장애 트리거
#       현실적인 서비스 저하 패턴으로 DR 감지 시간 검증
#
# 서비스 의존성 및 DR 트리거 조건:
#   - ECS 레이어: users + history + chatbot 동시 unhealthy (3회 연속, 30초 간격)
#   - ALB 헬스체크 실패 → UnhealthyHostCount ≥ 1 → 90초 후 ALARM
#   - ecs_layer_failure Composite Alarm ALARM 전환
#
# 액션 순서 (점진적 부하 증가):
#   Phase 1 - 부하 주입 (0분):
#     users CPU 95% + history CPU 95% + chatbot 메모리 95% 동시 주입
#     → 컨테이너 응답 지연 → ALB 헬스체크 타임아웃 시작
#   Phase 2 - 헬스체크 실패 누적 (3분 후):
#     users 태스크 50% 종료 (CPU 부하로 이미 unhealthy 상태에서 추가 타격)
#   Phase 3 - 연쇄 장애 (5분 후):
#     history 태스크 50% 종료
#     → users + history + chatbot 모두 UnhealthyHostCount ≥ 1
#     → ecs_layer_failure ALARM → DR Composite Alarm 조건 충족
#
# 타임라인:
#   T+0:00  CPU/메모리 부하 주입 시작
#   T+0:30  ALB 헬스체크 실패 시작 (첫 번째 평가)
#   T+1:30  ALB 헬스체크 3회 연속 실패 → UnhealthyHostCount 알람 ALARM
#   T+3:00  users 태스크 50% 종료
#   T+5:00  history 태스크 50% 종료
#   T+5:30  ecs_layer_failure Composite Alarm ALARM 전환
#   T+6:00  DR Composite Alarm 조건 평가 (Aurora/AgentCore 상태에 따라 트리거)
#
# 기대 결과:
#   - ALB가 부하 과중 태스크를 unhealthy로 점진적 감지
#   - ECS Auto Scaling이 scale-out 시도 (신규 태스크 기동)
#   - 신규 태스크 기동 중 서비스 부분 저하 (503 증가)
#   - ecs_layer_failure Composite Alarm ALARM 전환
#   - Aurora/AgentCore 레이어 정상 시: DR 미트리거 (ECS 단독 장애)
#   - Aurora/AgentCore 레이어 장애 동반 시: DR 트리거
#
# ⚠️  주의:
#   - CPU/메모리 부하 주입 후 ALB 헬스체크 실패까지 1~2분 소요
#   - ECS Auto Scaling scale-out이 발동되면 신규 태스크가 부하를 분산
#     → 알람이 OK로 복구될 수 있음 (Auto Scaling 동작 검증 포인트)
#   - stop_condition 알람이 ALARM 전환되면 실험 즉시 중단
# ============================================================

resource "aws_fis_experiment_template" "gradual_ecs_degradation" {
  description = "[시나리오 13] 점진적 ECS 서비스 저하 - CPU/메모리 부하 → ALB Unhealthy → ECS 레이어 DR 트리거 검증"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  # ── Phase 1: users 서비스 CPU 95% 부하 주입 ──────────────
  # ALB 헬스체크 타임아웃 유도 (응답 지연)
  action {
    name        = "cpu-stress-users"
    action_id   = "aws:ecs:task-cpu-stress"
    description = "users 서비스 CPU 95% 부하 주입 (ALB 헬스체크 타임아웃 유도)"

    parameter {
      key   = "duration"
      value = "PT12M"
    }

    parameter {
      key   = "percent"
      value = "95"
    }

    parameter {
      key   = "workers"
      value = "0" # vCPU 수만큼 자동
    }

    target {
      key   = "Tasks"
      value = "gradual-users-tasks"
    }
  }

  # ── Phase 1: history 서비스 CPU 95% 부하 주입 (동시) ─────
  action {
    name        = "cpu-stress-history"
    action_id   = "aws:ecs:task-cpu-stress"
    description = "history 서비스 CPU 95% 부하 주입 (ALB 헬스체크 타임아웃 유도)"

    parameter {
      key   = "duration"
      value = "PT12M"
    }

    parameter {
      key   = "percent"
      value = "95"
    }

    parameter {
      key   = "workers"
      value = "0"
    }

    target {
      key   = "Tasks"
      value = "gradual-history-tasks"
    }
  }

  # ── Phase 1: chatbot 서비스 CPU 95% 부하 주입 (동시) ──
  # aws:ecs:task-memory-stress 미지원 → cpu-stress로 대체
  action {
    name        = "memory-stress-chatbot"
    action_id   = "aws:ecs:task-cpu-stress"
    description = "chatbot 서비스 CPU 95% 부하 주입 (응답 지연 → ALB unhealthy 유도)"

    parameter {
      key   = "duration"
      value = "PT12M"
    }

    parameter {
      key   = "percent"
      value = "95"
    }

    parameter {
      key   = "workers"
      value = "0"
    }

    target {
      key   = "Tasks"
      value = "gradual-chatbot-tasks"
    }
  }

  # ── Phase 2 대기: 부하 주입 후 3분 대기 ─────────────────
  # ALB 헬스체크 3회 연속 실패(90초) + 여유 시간
  # start_after로 duration 완료를 기다리면 T+12분이 되므로
  # wait 액션으로 T+3분에 Phase 2 시작
  action {
    name        = "wait-phase2"
    action_id   = "aws:fis:wait"
    description = "Phase 2 시작 전 3분 대기 (ALB 헬스체크 실패 누적 대기)"

    parameter {
      key   = "duration"
      value = "PT3M"
    }
  }

  # ── Phase 2: users 태스크 50% 종료 (3분 후) ──────────────
  action {
    name        = "kill-half-users"
    action_id   = "aws:ecs:stop-task"
    description = "users 태스크 50% 종료 (Phase 2: 헬스체크 실패 가속)"

    start_after = ["wait-phase2"]

    target {
      key   = "Tasks"
      value = "gradual-users-tasks-kill"
    }
  }

  # ── Phase 3 대기: Phase 2 후 2분 대기 ────────────────────
  action {
    name        = "wait-phase3"
    action_id   = "aws:fis:wait"
    description = "Phase 3 시작 전 2분 대기"

    start_after = ["wait-phase2"]

    parameter {
      key   = "duration"
      value = "PT2M"
    }
  }

  # ── Phase 3: history 태스크 50% 종료 (5분 후) ────────────
  action {
    name        = "kill-half-history"
    action_id   = "aws:ecs:stop-task"
    description = "history 태스크 50% 종료 (Phase 3: ECS 레이어 장애 완성)"

    start_after = ["wait-phase3"]

    target {
      key   = "Tasks"
      value = "gradual-history-tasks-kill"
    }
  }

  # ── 타겟: users 태스크 (CPU 부하용, ALL) ──────────────────
  target {
    name           = "gradual-users-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"

    resource_tag {
      key   = "Service"
      value = "users"
    }

    filter {
      path   = "clusterArn"
      values = [data.terraform_remote_state.compute.outputs.ecs_cluster_id]
    }
  }

  # ── 타겟: history 태스크 (CPU 부하용, ALL) ────────────────
  target {
    name           = "gradual-history-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"

    resource_tag {
      key   = "Service"
      value = "history"
    }

    filter {
      path   = "clusterArn"
      values = [data.terraform_remote_state.compute.outputs.ecs_cluster_id]
    }
  }

  # ── 타겟: chatbot 태스크 (메모리 부하용, ALL) ─────────────
  target {
    name           = "gradual-chatbot-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"

    resource_tag {
      key   = "Service"
      value = "chatbot"
    }

    filter {
      path   = "clusterArn"
      values = [data.terraform_remote_state.compute.outputs.ecs_cluster_id]
    }
  }

  # ── 타겟: users 태스크 (종료용, 50%) ─────────────────────
  target {
    name           = "gradual-users-tasks-kill"
    resource_type  = "aws:ecs:task"
    selection_mode = "PERCENT(50)"

    resource_tag {
      key   = "Service"
      value = "users"
    }

    filter {
      path   = "clusterArn"
      values = [data.terraform_remote_state.compute.outputs.ecs_cluster_id]
    }
  }

  # ── 타겟: history 태스크 (종료용, 50%) ───────────────────
  target {
    name           = "gradual-history-tasks-kill"
    resource_type  = "aws:ecs:task"
    selection_mode = "PERCENT(50)"

    resource_tag {
      key   = "Service"
      value = "history"
    }

    filter {
      path   = "clusterArn"
      values = [data.terraform_remote_state.compute.outputs.ecs_cluster_id]
    }
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-GRADUAL-ECS-DEGRADATION"
    Scenario = "13-gradual-ecs-degradation"
  }
}

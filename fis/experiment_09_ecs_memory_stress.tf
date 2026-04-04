# ============================================================
# 시나리오 09: ECS 메모리 부하 주입
# ============================================================
# 목적: 메모리 기반 Auto Scaling 동작 검증
#       (target: 80% → scale-out 트리거 확인)
#       OOM Kill 발생 시 ECS 태스크 재시작 동작 확인
#
# 대상: chatbot 서비스 (WebSocket 세션 유지로 메모리 집약적)
#       태스크 메모리: 512MB
# 액션: CPU 90% 부하 + 태스크 강제 종료로 OOM 상황 시뮬레이션
#
# ⚠️  FIS 제약사항:
#   - aws:ecs:task-memory-stress 액션은 FIS에서 미지원
#   - CPU 부하(task-cpu-stress)로 응답 지연 → ALB 헬스체크 실패 유도
#   - 실제 OOM Kill 검증은 ECS Exec으로 수동 수행 필요:
#     aws ecs execute-command --cluster cdci-prd-cluster \
#       --task <task-id> --container chatbot --interactive \
#       --command "python3 -c \"a=[' '*1024*1024 for _ in range(600)]\""
#
# 기대 결과:
#   - CPU 과부하로 ALB 헬스체크 타임아웃 → UnhealthyHostCount 증가
#   - ECS Auto Scaling scale-out 트리거 (MemoryUtilization 알람 대신 CPU 알람)
#   - 태스크 강제 종료 후 ECS가 자동 재시작
#   - Redis 세션은 유지 (태스크 재시작과 무관)
# ============================================================

resource "aws_fis_experiment_template" "ecs_memory_stress" {
  description = "[시나리오 09] ECS CPU 부하 주입 - Auto Scaling 및 태스크 재시작 복구 검증 (chatbot)"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = local.stop_condition_alarm_arn
  }

  # ── Phase 1: chatbot 태스크에 CPU 90% 부하 8분 주입 ──────
  # ALB 헬스체크 타임아웃 유도 → UnhealthyHostCount 증가
  # → MemoryUtilization/CPUUtilization 알람 트리거 → scale-out 검증
  action {
    name        = "cpu-stress-chatbot"
    action_id   = "aws:ecs:task-cpu-stress"
    description = "chatbot 서비스 CPU 90% 부하 주입 (8분) - ALB 헬스체크 실패 및 Auto Scaling 검증"

    parameter {
      key   = "duration"
      value = "PT8M"
    }

    parameter {
      key   = "percent"
      value = "90"
    }

    parameter {
      key   = "workers"
      value = "0"
    }

    target {
      key   = "Tasks"
      value = "ecs-chatbot-tasks-stress"
    }
  }

  # ── Phase 2: 부하 주입 중 태스크 강제 종료 (5분 후) ──────
  # CPU 과부하 상태에서 태스크 종료 → ECS 자동 재시작 검증
  # Redis 세션 유지 여부 확인 포인트
  action {
    name        = "kill-stressed-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "CPU 부하 중 chatbot 태스크 강제 종료 - ECS 자동 재시작 및 Redis 세션 유지 검증"

    start_after = ["cpu-stress-chatbot"]

    target {
      key   = "Tasks"
      value = "ecs-chatbot-tasks-kill"
    }
  }

  # ── 타겟: chatbot 태스크 (CPU 부하용, ALL) ────────────────
  # ── 타겟: chatbot 태스크 (CPU 부하용, ALL) ────────────────
  target {
    name           = "ecs-chatbot-tasks-stress"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"
    resource_arns  = var.ecs_task_arns["chatbot"]
  }

  # ── 타겟: chatbot 태스크 (강제 종료용, 50%) ──────────────
  target {
    name           = "ecs-chatbot-tasks-kill"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"
    resource_arns  = var.ecs_task_arns["chatbot"]
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-ECS-MEMORY-STRESS"
    Scenario = "09-ecs-memory-stress"
  }
}

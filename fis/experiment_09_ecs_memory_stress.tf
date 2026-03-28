# ============================================================
# 시나리오 09: ECS 메모리 부하 주입
# ============================================================
# 목적: 메모리 기반 Auto Scaling 동작 검증
#       (target: 80% → scale-out 트리거 확인)
#       OOM Kill 발생 시 ECS 태스크 재시작 동작 확인
#
# 대상: chatbot 서비스 (WebSocket 세션 유지로 메모리 집약적)
#       태스크 메모리: 512MB
# 액션: 메모리 90% 부하를 8분간 주입
# 기대 결과:
#   - MemoryUtilization > 80% 지속 시 scale-out 발생
#   - OOM Kill 발생 시 ECS가 태스크 자동 재시작
#   - WebSocket 연결 끊김 → 클라이언트 재연결 로직 동작 확인
#   - Redis 세션은 유지 (태스크 재시작과 무관)
# ============================================================

resource "aws_fis_experiment_template" "ecs_memory_stress" {
  description = "[시나리오 09] ECS 메모리 부하 주입 - Auto Scaling 및 OOM 복구 검증 (chatbot)"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  # ── 액션: chatbot 태스크에 CPU 90% 부하 8분 주입 ────────
  # aws:ecs:task-memory-stress 미지원 → cpu-stress로 대체
  # chatbot 서비스 CPU 과부하로 응답 지연 → ALB 헬스체크 실패 유도
  action {
    name        = "memory-stress-chatbot"
    action_id   = "aws:ecs:task-cpu-stress"
    description = "chatbot 서비스 CPU 90% 부하 주입 (8분, 메모리 스트레스 대체)"

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
      value = "ecs-chatbot-tasks-memory"
    }
  }

  target {
    name           = "ecs-chatbot-tasks-memory"
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

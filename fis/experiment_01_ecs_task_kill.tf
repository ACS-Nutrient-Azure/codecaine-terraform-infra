# ============================================================
# 시나리오 01: ECS 태스크 강제 종료
# ============================================================
# 목적: ECS 서비스의 자동 복구(desired_count 유지) 및
#       ALB 헬스체크 기반 트래픽 재라우팅 검증
#
# 대상: users, history, chatbot, analysis, frontend 서비스
# 액션: 각 서비스의 실행 중인 태스크를 50% 강제 종료
# 기대 결과:
#   - ECS가 새 태스크를 자동 재시작 (< 60초)
#   - ALB가 unhealthy 태스크로의 트래픽 차단
#   - deployment_circuit_breaker가 연속 실패 시 롤백
# ============================================================

resource "aws_fis_experiment_template" "ecs_task_kill" {
  description = "[시나리오 01] ECS 태스크 강제 종료 - 자동 복구 검증"
  role_arn    = aws_iam_role.fis.arn

  # 실험 중단 조건: DR Composite Alarm이 ALARM 상태가 되면 즉시 중단
  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  # ── 액션 1: users 서비스 태스크 50% 종료 ──────────────────
  action {
    name        = "kill-users-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "users 서비스 ECS 태스크 강제 종료"

    target {
      key   = "Tasks"
      value = "ecs-users-tasks"
    }
  }

  # ── 액션 2: chatbot 서비스 태스크 50% 종료 (1분 후) ───────
  action {
    name        = "kill-chatbot-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "chatbot 서비스 ECS 태스크 강제 종료"

    start_after = ["kill-users-tasks"]

    target {
      key   = "Tasks"
      value = "ecs-chatbot-tasks"
    }
  }

  # ── 타겟: users 서비스 태스크 (50%) ───────────────────────
  target {
    name           = "ecs-users-tasks"
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

  # ── 타겟: chatbot 서비스 태스크 (50%) ─────────────────────
  target {
    name           = "ecs-chatbot-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "PERCENT(50)"

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
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-ECS-TASK-KILL"
    Scenario = "01-ecs-task-kill"
  }
}

# ============================================================
# 시나리오 10: 멀티 서비스 연쇄 장애 (Cascade Failure)
# ============================================================
# 목적: 서비스 간 의존성 체인에서의 연쇄 장애 전파 및
#       Circuit Breaker / Graceful Degradation 동작 검증
#
# 서비스 의존성 체인:
#   frontend → chatbot → analysis → users (Cloud Map 내부 통신)
#   chatbot → Redis (세션)
#   analysis → AgentCore Runtime (Bedrock)
#   users → S3 codef-data, Textract
#
# 액션 순서 (연쇄 장애 시뮬레이션):
#   1. analysis 서비스 태스크 전체 종료 (AI 분석 불가)
#   2. 2분 후: chatbot 서비스 CPU 100% 부하 (분석 결과 대기 타임아웃)
#   3. 2분 후: users 서비스 태스크 50% 종료 (인증 부하 증가)
#
# 기대 결과:
#   - analysis 장애 시 chatbot이 fallback 응답 반환 (500 아닌 503)
#   - chatbot CPU 급증 시 Auto Scaling 발동
#   - users 50% 종료 시 ALB가 정상 태스크로만 라우팅
#   - deployment_circuit_breaker가 연속 실패 감지 시 롤백 방지
#   - 전체 서비스 완전 중단 없이 부분 기능 저하로 유지
# ============================================================

resource "aws_fis_experiment_template" "multi_service_cascade" {
  description = "[시나리오 10] 멀티 서비스 연쇄 장애 - 의존성 체인 복원력 및 Graceful Degradation 검증"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  # ── 액션 1: analysis 서비스 전체 태스크 종료 ──────────────
  action {
    name        = "kill-analysis-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "analysis 서비스 전체 태스크 종료 (AI 분석 불가)"

    target {
      key   = "Tasks"
      value = "cascade-analysis-tasks"
    }
  }

  # ── 액션 2: chatbot CPU 100% 부하 (2분 후) ────────────────
  action {
    name        = "cpu-stress-chatbot-cascade"
    action_id   = "aws:ecs:task-cpu-stress"
    description = "chatbot CPU 100% 부하 (분석 대기 타임아웃 시뮬레이션)"

    start_after = ["kill-analysis-tasks"]

    parameter {
      key   = "duration"
      value = "PT6M"
    }

    parameter {
      key   = "percent"
      value = "100"
    }

    parameter {
      key   = "workers"
      value = "0"
    }

    target {
      key   = "Tasks"
      value = "cascade-chatbot-tasks"
    }
  }

  # ── 액션 3: users 서비스 50% 태스크 종료 (2분 후) ─────────
  action {
    name        = "kill-half-users-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "users 서비스 50% 태스크 종료 (인증 부하 증가)"

    start_after = ["cpu-stress-chatbot-cascade"]

    target {
      key   = "Tasks"
      value = "cascade-users-tasks"
    }
  }

  # ── 타겟 정의 ─────────────────────────────────────────────

  target {
    name           = "cascade-analysis-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"

    resource_tag {
      key   = "Service"
      value = "analysis"
    }

    filter {
      path   = "clusterArn"
      values = [data.terraform_remote_state.compute.outputs.ecs_cluster_id]
    }
  }

  target {
    name           = "cascade-chatbot-tasks"
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

  target {
    name           = "cascade-users-tasks"
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

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-CASCADE-FAILURE"
    Scenario = "10-multi-service-cascade"
  }
}

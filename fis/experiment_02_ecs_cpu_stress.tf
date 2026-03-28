# ============================================================
# 시나리오 02: ECS CPU 부하 주입
# ============================================================
# 목적: CPU 기반 Auto Scaling 동작 검증
#       (target: 70% → scale-out 트리거 확인)
#
# 대상: analysis 서비스 (AI 추론 워크로드, CPU 집약적)
# 액션: CPU 90% 부하를 10분간 주입
# 기대 결과:
#   - CPUUtilization > 70% 지속 시 scale-out 발생
#   - scale-out cooldown(60초) 내 새 태스크 기동
#   - 부하 해제 후 scale-in cooldown(300초) 후 정상화
# ============================================================

resource "aws_fis_experiment_template" "ecs_cpu_stress" {
  description = "[시나리오 02] ECS CPU 부하 주입 - Auto Scaling 검증 (analysis 서비스)"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  # ── 액션: analysis 태스크에 CPU 90% 부하 10분 주입 ────────
  action {
    name        = "cpu-stress-analysis"
    action_id   = "aws:ecs:task-cpu-stress"
    description = "analysis 서비스 CPU 90% 부하 주입 (10분)"

    parameter {
      key   = "duration"
      value = "PT10M"
    }

    parameter {
      key   = "percent"
      value = "90"
    }

    parameter {
      key   = "workers"
      value = "0" # 0 = vCPU 수만큼 자동
    }

    target {
      key   = "Tasks"
      value = "ecs-analysis-tasks"
    }
  }

  target {
    name           = "ecs-analysis-tasks"
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

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-ECS-CPU-STRESS"
    Scenario = "02-ecs-cpu-stress"
  }
}

# ============================================================
# 시나리오 02: ECS CPU 부하 주입
# ============================================================
# 목적: CPU 기반 Auto Scaling 동작 검증
#
# ▶ 실험 전 terraform.tfvars의 ecs_task_arns 업데이트 후 terraform apply
# ============================================================

resource "aws_fis_experiment_template" "ecs_cpu_stress" {
  description = "[시나리오 02] ECS CPU 부하 주입 - Auto Scaling 검증 (analysis 서비스)"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = local.stop_condition_alarm_arn
  }

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
      value = "0"
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
    resource_arns  = [var.ecs_task_arns["analysis"]]
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

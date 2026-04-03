# ============================================================
# 시나리오 01: ECS 태스크 강제 종료
# ============================================================
# 목적: ECS 서비스의 자동 복구(desired_count 유지) 및
#       ALB 헬스체크 기반 트래픽 재라우팅 검증
#
# ▶ 실험 전 terraform.tfvars의 ecs_task_arns 업데이트 후 terraform apply
#   aws ecs list-tasks --cluster cdci-prd-cluster \
#     --service-name cdci-prd-<service>-service --region ap-northeast-2
# ============================================================

resource "aws_fis_experiment_template" "ecs_task_kill" {
  description = "[시나리오 01] ECS 태스크 강제 종료 - 자동 복구 검증"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = local.stop_condition_alarm_arn
  }

  action {
    name        = "kill-users-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "users 서비스 ECS 태스크 강제 종료"
    target {
      key   = "Tasks"
      value = "ecs-users-tasks"
    }
  }

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

  action {
    name        = "kill-analysis-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "analysis 서비스 ECS 태스크 강제 종료"
    start_after = ["kill-chatbot-tasks"]
    target {
      key   = "Tasks"
      value = "ecs-analysis-tasks"
    }
  }

  action {
    name        = "kill-history-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "history 서비스 ECS 태스크 강제 종료"
    start_after = ["kill-analysis-tasks"]
    target {
      key   = "Tasks"
      value = "ecs-history-tasks"
    }
  }

  target {
    name           = "ecs-users-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"
    resource_arns  = [var.ecs_task_arns["users"]]
  }

  target {
    name           = "ecs-chatbot-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"
    resource_arns  = [var.ecs_task_arns["chatbot"]]
  }

  target {
    name           = "ecs-analysis-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"
    resource_arns  = [var.ecs_task_arns["analysis"]]
  }

  target {
    name           = "ecs-history-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "ALL"
    resource_arns  = [var.ecs_task_arns["history"]]
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

# ============================================================
# 시나리오 08: DR 트리거 시뮬레이션 (복합 장애)
# ============================================================
# 목적: DR Composite Alarm 트리거 조건 검증 및
#       Step Functions DR Orchestrator 자동 실행 확인
#
# DR 트리거 조건 (alarms.tf 기준):
#   - ECS 레이어 장애 (users + history + chatbot 동시 unhealthy)
#     AND Aurora 레이어 장애 (2개 이상 클러스터 연결 없음)
#   - Aurora 레이어 장애 AND AgentCore 헬스체크 실패
#   - ECS 레이어 장애 AND AgentCore 헬스체크 실패
#
# 액션 순서:
#   1. users, history, chatbot ECS 태스크 전체 종료 (ECS 레이어 장애)
#   2. 30초 대기 → ALB UnhealthyHostCount 알람 발생 확인
#   3. analysis, chatbot Aurora 클러스터 연결 차단 (Aurora 레이어 장애)
#   → Composite Alarm ALARM → EventBridge → Step Functions 실행
#
# 기대 결과:
#   - DR Composite Alarm이 ALARM 상태로 전환
#   - EventBridge가 Step Functions DR Orchestrator 실행
#   - Step Functions: Aurora Failover → ECS 활성화 → AgentCore 프로비저닝
#   - Route53 Failover Record가 도쿄 ALB로 전환
#
# ⚠️  주의: 이 실험은 실제 DR을 트리거합니다.
#           반드시 DR 인프라(dr/ 모듈)가 배포된 상태에서 실행하세요.
#           실험 후 수동으로 서울 리전 복구 필요.
# ============================================================

resource "aws_fis_experiment_template" "dr_trigger_simulation" {
  description = "[시나리오 08] DR 트리거 시뮬레이션 - 복합 장애로 서울→도쿄 자동 Failover 검증"
  role_arn    = aws_iam_role.fis.arn

  # DR 실험은 stop_condition을 별도 알람으로 설정
  # (DR Composite Alarm 자체가 트리거이므로 다른 알람 사용)
  stop_condition {
    source = "none"
  }

  # ── 액션 1: users 서비스 태스크 전체 종료 ─────────────────
  action {
    name        = "kill-all-users-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "users 서비스 전체 태스크 종료"

    target {
      key   = "Tasks"
      value = "dr-sim-users-tasks"
    }
  }

  # ── 액션 2: history 서비스 태스크 전체 종료 ───────────────
  action {
    name        = "kill-all-history-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "history 서비스 전체 태스크 종료"

    start_after = ["kill-all-users-tasks"]

    target {
      key   = "Tasks"
      value = "dr-sim-history-tasks"
    }
  }

  # ── 액션 3: chatbot 서비스 태스크 전체 종료 ───────────────
  action {
    name        = "kill-all-chatbot-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "chatbot 서비스 전체 태스크 종료"

    start_after = ["kill-all-history-tasks"]

    target {
      key   = "Tasks"
      value = "dr-sim-chatbot-tasks"
    }
  }

  # ── 액션 4: analysis-cluster 네트워크 차단 (Aurora 레이어 장애) ──
  action {
    name        = "block-db-subnet-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "DB Subnet 2a 차단 (Aurora 연결 불가 시뮬레이션)"

    start_after = ["kill-all-chatbot-tasks"]

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
      value = "dr-sim-db-subnet-2a"
    }
  }

  action {
    name        = "block-db-subnet-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "DB Subnet 2c 차단 (Aurora 연결 불가 시뮬레이션)"

    start_after = ["block-db-subnet-2a"]

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
      value = "dr-sim-db-subnet-2c"
    }
  }

  # ── 타겟 정의 ─────────────────────────────────────────────

  target {
    name           = "dr-sim-users-tasks"
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

  target {
    name           = "dr-sim-history-tasks"
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

  target {
    name           = "dr-sim-chatbot-tasks"
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
    name           = "dr-sim-db-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-DB-2A"
    }
  }

  target {
    name           = "dr-sim-db-subnet-2c"
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
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-DR-TRIGGER-SIM"
    Scenario = "08-dr-trigger-simulation"
  }
}

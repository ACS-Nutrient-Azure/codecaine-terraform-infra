# ============================================================
# 시나리오 14: 리전 수준 장애 시뮬레이션 (Region-Level Failure)
# ============================================================
# 목적: 서울 리전 전체 장애를 모사하는 복합 시나리오
#       Public Subnet + DB Subnet 동시 차단으로
#       ECS 레이어 + Aurora 레이어 동시 장애 → DR Composite Alarm 트리거
#
# 액션 순서:
#   T+0:00  experiment-start (1분 앵커)
#   T+1:00  Public 2a, Public 2c, DB 2a, DB 2c 동시 차단 (20분)
#   T+2:30  ALB UnhealthyHostCount 알람 ALARM
#   T+3:00  DatabaseConnections=0 알람 ALARM
#   T+3:00  DR-TRIGGER ALARM → Step Functions 실행
#   T+21:00 실험 종료, NACL 자동 복구
# ============================================================

resource "aws_fis_experiment_template" "region_level_failure" {
  description = "[시나리오 14] 리전 수준 장애 시뮬레이션 - Public+DB Subnet 동시 차단으로 전체 DR 파이프라인 검증"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = local.stop_condition_alarm_arn
  }

  # ── 앵커: 모든 차단 액션의 동시 시작 기준점 ──────────────
  action {
    name        = "experiment-start"
    action_id   = "aws:fis:wait"
    description = "실험 시작 앵커 (1분)"

    parameter {
      key   = "duration"
      value = "PT1M"
    }
  }

  # ── Public Subnet 2a 차단 ────────────────────────────────
  action {
    name        = "block-public-subnet-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Public Subnet 2a 완전 차단"

    start_after = ["experiment-start"]

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
      value = "region-public-subnet-2a"
    }
  }

  # ── Public Subnet 2c 차단 ────────────────────────────────
  action {
    name        = "block-public-subnet-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Public Subnet 2c 완전 차단"

    start_after = ["experiment-start"]

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
      value = "region-public-subnet-2c"
    }
  }

  # ── DB Subnet 2a 차단 ────────────────────────────────────
  action {
    name        = "block-db-subnet-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "DB Subnet 2a 완전 차단"

    start_after = ["experiment-start"]

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
      value = "region-db-subnet-2a"
    }
  }

  # ── DB Subnet 2c 차단 ────────────────────────────────────
  action {
    name        = "block-db-subnet-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "DB Subnet 2c 완전 차단"

    start_after = ["experiment-start"]

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
      value = "region-db-subnet-2c"
    }
  }

  # ── 타겟 정의 ─────────────────────────────────────────────

  target {
    name           = "region-public-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PUBLIC-2A"
    }
  }

  target {
    name           = "region-public-subnet-2c"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PUBLIC-2C"
    }
  }

  target {
    name           = "region-db-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-DB-2A"
    }
  }

  target {
    name           = "region-db-subnet-2c"
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
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-REGION-LEVEL-FAILURE"
    Scenario = "14-region-level-failure"
  }
}

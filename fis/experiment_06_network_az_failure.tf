# ============================================================
# 시나리오 06: AZ 장애 시뮬레이션 (Network Disruption)
# ============================================================
# 목적: ap-northeast-2a AZ 장애 시 ap-northeast-2c로의
#       자동 트래픽 전환 및 멀티-AZ 복원력 검증
#
# 구성:
#   - Public Subnet:      10.0.1.0/24 (2a), 10.0.2.0/24 (2c)
#   - Private App Subnet: 10.0.11.0/24 (2a), 10.0.12.0/24 (2c)
#   - Private DB Subnet:  10.0.21.0/24 (2a), 10.0.22.0/24 (2c)
#
# 액션: 2a Private App Subnet에 NACL로 모든 트래픽 차단
#       (ALB → ECS 태스크 통신 차단 시뮬레이션)
# 기대 결과:
#   - ALB가 2a 태스크를 unhealthy로 감지 후 2c로만 라우팅
#   - Aurora가 2a Writer 장애 시 2c Reader로 자동 페일오버
#   - ECS Auto Scaling이 2c에 추가 태스크 기동
#   - 전체 서비스 가용성 유지 (일부 지연 허용)
#
# 주의: NACL 기반 차단이므로 실험 종료 시 자동 복구됨
# ============================================================

resource "aws_fis_experiment_template" "network_az_failure" {
  description = "[시나리오 06] AZ 장애 시뮬레이션 - 2a Private App Subnet 네트워크 차단"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }

  # ── 액션: 2a Private App Subnet 네트워크 차단 (15분) ──────
  action {
    name        = "disrupt-az-2a-private-app"
    action_id   = "aws:network:disrupt-connectivity"
    description = "ap-northeast-2a Private App Subnet 네트워크 차단 (15분)"

    parameter {
      key   = "duration"
      value = "PT15M"
    }

    parameter {
      key   = "scope"
      value = "all" # ingress + egress 모두 차단
    }

    target {
      key   = "Subnets"
      value = "private-app-subnet-2a"
    }
  }

  # ── 타겟: 2a Private App Subnet ───────────────────────────
  target {
    name           = "private-app-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-APP-2A"
    }
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-NETWORK-AZ-FAILURE"
    Scenario = "06-network-az-failure"
  }
}

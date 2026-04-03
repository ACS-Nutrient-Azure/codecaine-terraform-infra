# ============================================================
# 시나리오 07: NAT Gateway 장애 시뮬레이션
# ============================================================
# 목적: 단일 NAT Gateway 장애 시 ECS 서비스의 외부 통신
#       (ECR 이미지 pull, Bedrock API, Secrets Manager 등) 영향 검증
#
# 구성: 단일 NAT Gateway (ap-northeast-2a Public Subnet)
#       → Private App Route Table의 0.0.0.0/0 경로
#
# 액션: Private App Subnet의 NAT Gateway 경유 트래픽 차단
#       (인터넷 egress 차단, VPC 내부 통신은 유지)
# 기대 결과:
#   - 실행 중인 ECS 태스크는 정상 동작 (이미 기동된 컨테이너)
#   - 신규 태스크 기동 시 ECR pull 실패 → 태스크 시작 불가
#   - Bedrock AgentCore API 호출 실패 → analysis/chatbot 서비스 오류
#   - Secrets Manager 신규 조회 실패 (캐시된 값은 유지)
#   - VPC Endpoint 경유 서비스(S3, SSM 등)는 정상 유지
#
# 참고: VPC Endpoint가 없는 서비스만 영향받음
# ============================================================

resource "aws_fis_experiment_template" "nat_gateway_failure" {
  description = "[시나리오 07] NAT Gateway 장애 - 외부 통신 의존성 및 VPC Endpoint 우회 검증"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = local.stop_condition_alarm_arn
  }

  # ── 액션: Private App Subnet egress 차단 (10분) ───────────
  # ⚠️  FIS 제약사항: aws:network:disrupt-connectivity는 scope = "all"만 지원
  #   - ingress/egress 방향 구분 불가, 서브넷 전체 트래픽 차단
  #   - VPC 내부 통신(ECS ↔ RDS, ECS ↔ Redis)도 함께 차단됨
  #   - 의도치 않게 DR Composite Alarm 트리거 가능성 있음
  #   - 실험 전 DR Composite Alarm을 수동으로 비활성화 권장
  action {
    name        = "block-nat-egress-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Private App Subnet 2a 인터넷 egress 차단 (NAT 장애 시뮬레이션)"

    parameter {
      key   = "duration"
      value = "PT10M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "private-app-subnet-2a-nat"
    }
  }

  action {
    name        = "block-nat-egress-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Private App Subnet 2c 인터넷 egress 차단 (NAT 장애 시뮬레이션)"

    start_after = ["block-nat-egress-2a"]

    parameter {
      key   = "duration"
      value = "PT10M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "private-app-subnet-2c-nat"
    }
  }

  # ── 타겟: Private App Subnet 2a ───────────────────────────
  target {
    name           = "private-app-subnet-2a-nat"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-APP-2A"
    }
  }

  # ── 타겟: Private App Subnet 2c ───────────────────────────
  target {
    name           = "private-app-subnet-2c-nat"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-APP-2C"
    }
  }

  log_configuration {
    log_schema_version = 2
    cloudwatch_logs_configuration {
      log_group_arn = "${aws_cloudwatch_log_group.fis.arn}:*"
    }
  }

  tags = {
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-NAT-FAILURE"
    Scenario = "07-nat-gateway-failure"
  }
}

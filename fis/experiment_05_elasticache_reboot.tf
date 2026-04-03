# ============================================================
# 시나리오 05: ElastiCache Redis 장애 시뮬레이션
# ============================================================
# 목적: Redis 장애 시 chatbot 서비스의 세션/캐시 복구력 검증
#
# 대상: cdci-prd-chatbot-redis (chatbot 전용 Redis, cache.t3.micro 단일 노드)
#
# ⚠️  FIS 제약사항:
#   - aws:elasticache:reboot-cache-cluster 액션의 타겟 키는 "ReplicationGroups"
#   - 단, cache.t3.micro 단일 노드는 Replication Group이 없으므로
#     네트워크 차단 방식으로 Redis 장애를 시뮬레이션
#
# 액션: chatbot Redis가 위치한 Private App Subnet egress 차단
#       → ECS 태스크 → Redis 연결 불가 (Redis 자체는 정상이나 접근 불가)
#       → 세션 조회 실패 → graceful degradation 검증
#
# 기대 결과:
#   - Redis 연결 실패 시 chatbot 서비스가 500이 아닌 401/503 반환
#   - 세션 데이터 접근 불가 시 사용자 재로그인 유도
#   - 실험 종료(NACL 복구) 후 Redis 재연결 및 세션 정상화 확인
#
# 참고: Redis 자체 재부팅이 필요하다면 AWS 콘솔 또는 CLI로 수동 수행
#   aws elasticache reboot-cache-cluster \
#     --cache-cluster-id cdci-prd-chatbot-redis \
#     --cache-node-ids-to-reboot 0001
# ============================================================

resource "aws_fis_experiment_template" "elasticache_reboot" {
  description = "[시나리오 05] ElastiCache Redis 장애 시뮬레이션 - chatbot 세션 복구력 검증 (네트워크 차단 방식)"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = local.stop_condition_alarm_arn
  }

  # ── 액션: Private App Subnet 2a → Redis 방향 egress 차단 (8분) ──
  # ⚠️  FIS 제약사항: aws:network:disrupt-connectivity는 scope = "all"만 지원
  #   - ingress/egress 방향 구분 불가, 서브넷 전체 트래픽 차단
  #   - VPC 내부 통신(ECS ↔ RDS 등)도 함께 차단됨
  #   - 의도치 않게 DR Composite Alarm 트리거 가능성 있음
  #   - 실험 전 DR Composite Alarm을 수동으로 비활성화 권장
  action {
    name        = "block-redis-egress-2a"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Private App Subnet 2a egress 차단 (ECS → Redis 연결 불가)"

    parameter {
      key   = "duration"
      value = "PT8M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "chatbot-app-subnet-2a"
    }
  }

  action {
    name        = "block-redis-egress-2c"
    action_id   = "aws:network:disrupt-connectivity"
    description = "Private App Subnet 2c egress 차단 (ECS → Redis 연결 불가)"

    start_after = ["block-redis-egress-2a"]

    parameter {
      key   = "duration"
      value = "PT7M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "chatbot-app-subnet-2c"
    }
  }

  # ── 타겟: Private App Subnet 2a ───────────────────────────
  target {
    name           = "chatbot-app-subnet-2a"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag {
      key   = "Name"
      value = "CDCI-PRD-VPC-PRIVATE-APP-2A"
    }
  }

  # ── 타겟: Private App Subnet 2c ───────────────────────────
  target {
    name           = "chatbot-app-subnet-2c"
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
    Name     = "${upper(var.project_name)}-${upper(var.environment)}-FIS-REDIS-REBOOT"
    Scenario = "05-elasticache-reboot"
  }
}

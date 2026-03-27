# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = local.private_app_subnet_ids

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-REDIS-SUBNET-GROUP"
  }
}

# Redis 커스텀 파라미터 그룹
# maxmemory-policy: allkeys-lru (메모리 초과 시 LRU 방식으로 키 제거)
# maxmemory-samples: 10 (LRU 샘플 수, 높을수록 정확하지만 CPU 사용 증가)
resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.project_name}-${var.environment}-redis7-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  # TTL 86400초 = 24시간 (키 생성 시 애플리케이션에서 EXPIRE 설정 필요)
  # ElastiCache 파라미터 그룹에서 전역 TTL 설정은 지원하지 않음
  # 애플리케이션 코드에서 SET key value EX 86400 으로 설정해야 함

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-REDIS7-PARAMS"
  }
}

# ElastiCache Redis Cluster (chatbot 전용)
resource "aws_elasticache_cluster" "chatbot" {
  cluster_id           = "${var.project_name}-${var.environment}-chatbot-redis"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [local.redis_security_group_id]

  snapshot_retention_limit = 0
  apply_immediately        = true

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-CHATBOT-REDIS"
  }
}

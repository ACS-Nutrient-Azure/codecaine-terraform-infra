# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = local.private_app_subnet_ids

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-REDIS-SUBNET-GROUP"
  }
}

# ElastiCache Redis Cluster (chatbot 전용)
resource "aws_elasticache_cluster" "chatbot" {
  cluster_id           = "${var.project_name}-${var.environment}-chatbot-redis"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [local.redis_security_group_id]

  snapshot_retention_limit = 0 # 비용 절감 (필요 시 증가)
  apply_immediately        = true

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-CHATBOT-REDIS"
  }
}

# Aurora Cluster Outputs
output "aurora_cluster_endpoints" {
  description = "Aurora cluster endpoints"
  value = {
    cluster1 = aws_rds_cluster.aurora_cluster1.endpoint
    cluster2 = aws_rds_cluster.aurora_cluster2.endpoint
    cluster3 = aws_rds_cluster.aurora_cluster3.endpoint
  }
}

output "aurora_cluster_reader_endpoints" {
  description = "Aurora cluster reader endpoints"
  value = {
    cluster1 = aws_rds_cluster.aurora_cluster1.reader_endpoint
    cluster2 = aws_rds_cluster.aurora_cluster2.reader_endpoint
    cluster3 = aws_rds_cluster.aurora_cluster3.reader_endpoint
  }
}

output "aurora_cluster_arns" {
  description = "Aurora cluster ARNs"
  value = {
    cluster1 = aws_rds_cluster.aurora_cluster1.arn
    cluster2 = aws_rds_cluster.aurora_cluster2.arn
    cluster3 = aws_rds_cluster.aurora_cluster3.arn
  }
}

output "aurora_global_cluster_ids" {
  description = "Aurora global cluster IDs"
  value = var.enable_global_database ? {
    cluster1 = aws_rds_global_cluster.aurora_cluster1[0].id
    cluster2 = aws_rds_global_cluster.aurora_cluster2[0].id
    cluster3 = aws_rds_global_cluster.aurora_cluster3[0].id
  } : {}
}

output "aurora_secret_arns" {
  description = "Aurora password secret ARNs"
  value = {
    cluster1 = aws_secretsmanager_secret.cluster1.arn
    cluster2 = aws_secretsmanager_secret.cluster2.arn
    cluster3 = aws_secretsmanager_secret.cluster3.arn
  }
  sensitive = true
}

output "aurora_database_names" {
  description = "Aurora database names"
  value = {
    for k, v in var.aurora_clusters : k => v.database_name
  }
}

# Network Outputs (독립 모드)
output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "private_db_subnet_ids" {
  description = "Private DB subnet IDs"
  value       = local.private_db_subnet_ids
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = local.db_subnet_group_name
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = local.rds_security_group_id
}

# VPC peering is not used in this module as it uses the foundation VPC directly

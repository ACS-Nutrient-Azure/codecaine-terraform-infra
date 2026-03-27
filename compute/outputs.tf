output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_domain_name" {
  description = "Custom domain name (subdomain.domain)"
  value       = var.domain_name != "" ? "${var.subdomain_prefix}.${var.domain_name}" : aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "ALB Zone ID for Route53"
  value       = aws_lb.main.zone_id
}

output "target_group_arns" {
  description = "Target Group ARNs"
  value = {
    for k, v in aws_lb_target_group.services : k => v.arn
  }
}

output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_names" {
  description = "ECS Service names"
  value = {
    for k, v in aws_ecs_service.services : k => v.name
  }
}

output "ecs_task_definition_arns" {
  description = "ECS Task Definition ARNs"
  value = {
    for k, v in aws_ecs_task_definition.services : k => v.arn
  }
}

output "cloudwatch_log_group_names" {
  description = "CloudWatch Log Group names"
  value = {
    for k, v in aws_cloudwatch_log_group.services : k => v.name
  }
}

output "services_with_images" {
  description = "Services that have images in ECR and were deployed"
  value       = keys(local.services)
}

# Network Outputs (독립 모드)
output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = local.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private app subnet IDs"
  value       = local.private_app_subnet_ids
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = local.alb_security_group_id
}

output "ecs_tasks_security_group_id" {
  description = "ECS tasks security group ID"
  value       = local.ecs_tasks_security_group_id
}

# Bastion Host Outputs
output "bastion_instance_id" {
  description = "Bastion host instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = aws_eip.bastion.public_ip
}

output "bastion_security_group_id" {
  description = "Bastion host security group ID"
  value       = aws_security_group.bastion.id
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint for chatbot"
  value       = aws_elasticache_cluster.chatbot.cache_nodes[0].address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_cluster.chatbot.port
}

# DR Failover 모듈에서 참조하는 outputs
output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffixes" {
  description = "Target Group ARN suffixes for CloudWatch metrics"
  value = {
    for k, v in aws_lb_target_group.services : k => v.arn_suffix
  }
}

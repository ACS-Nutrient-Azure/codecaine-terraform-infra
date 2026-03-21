output "replication_instance_arn" {
  description = "DMS 복제 인스턴스 ARN"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "replication_instance_id" {
  description = "DMS 복제 인스턴스 ID"
  value       = aws_dms_replication_instance.main.replication_instance_id
}

output "source_endpoint_arn" {
  description = "Source endpoint ARN (users-cluster)"
  value       = aws_dms_endpoint.source_users.endpoint_arn
}

output "target_endpoint_arn" {
  description = "Target endpoint ARN (analysis-cluster)"
  value       = aws_dms_endpoint.target_analysis.endpoint_arn
}

output "replication_task_arn" {
  description = "DMS 복제 태스크 ARN"
  value       = aws_dms_replication_task.user_to_analysis.replication_task_arn
}

output "users_logical_param_group_name" {
  description = "users Logical Replication 파라미터 그룹 이름 (apply 후 README 1-1 단계 참고)"
  value = var.use_aurora ? aws_rds_cluster_parameter_group.users_logical[0].name : aws_db_parameter_group.users_logical[0].name
}

output "dms_security_group_id" {
  description = "DMS 복제 인스턴스 Security Group ID"
  value       = aws_security_group.dms.id
}

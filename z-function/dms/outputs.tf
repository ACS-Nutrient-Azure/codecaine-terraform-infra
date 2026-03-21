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
  description = <<EOT
users-cluster Logical Replication 파라미터 그룹 이름
apply 완료 후 아래 명령어로 users-cluster에 적용 후 재시작 필요:

  aws rds modify-db-cluster \
    --db-cluster-identifier cdci-prd-users-cluster \
    --db-cluster-parameter-group-name <이 값> \
    --apply-immediately

  aws rds reboot-db-instance \
    --db-instance-identifier cdci-prd-users-cluster-wo
EOT
  value = aws_rds_cluster_parameter_group.users_logical.name
}

output "dms_security_group_id" {
  description = "DMS 복제 인스턴스 Security Group ID"
  value       = aws_security_group.dms.id
}

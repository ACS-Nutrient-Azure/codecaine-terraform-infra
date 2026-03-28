output "fis_role_arn" {
  description = "FIS IAM Role ARN"
  value       = aws_iam_role.fis.arn
}

output "fis_log_group_name" {
  description = "FIS 실험 결과 CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.fis.name
}

output "fis_sns_topic_arn" {
  description = "FIS 알림 SNS Topic ARN"
  value       = aws_sns_topic.fis_notifications.arn
}

output "experiment_template_ids" {
  description = "생성된 FIS 실험 템플릿 ID 목록"
  value = {
    "01_ecs_task_kill"              = aws_fis_experiment_template.ecs_task_kill.id
    "02_ecs_cpu_stress"             = aws_fis_experiment_template.ecs_cpu_stress.id
    "03_aurora_failover"            = aws_fis_experiment_template.aurora_failover.id
    "04_aurora_reboot"              = aws_fis_experiment_template.aurora_reboot.id
    "05_elasticache_reboot"         = aws_fis_experiment_template.elasticache_reboot.id
    "06_network_az_failure"         = aws_fis_experiment_template.network_az_failure.id
    "07_nat_gateway_failure"        = aws_fis_experiment_template.nat_gateway_failure.id
    "08_dr_trigger_simulation"      = aws_fis_experiment_template.dr_trigger_simulation.id
    "09_ecs_memory_stress"          = aws_fis_experiment_template.ecs_memory_stress.id
    "10_multi_service_cascade"      = aws_fis_experiment_template.multi_service_cascade.id
    "11_aurora_global_db_isolation" = aws_fis_experiment_template.aurora_global_db_isolation.id
    "12_agentcore_layer_failure"    = aws_fis_experiment_template.agentcore_layer_failure.id
    "13_gradual_ecs_degradation"    = aws_fis_experiment_template.gradual_ecs_degradation.id
    "14_region_level_failure"       = aws_fis_experiment_template.region_level_failure.id
  }
}

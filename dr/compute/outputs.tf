output "dr_alb_dns_name" { value = aws_lb.dr.dns_name }
output "dr_alb_zone_id" { value = aws_lb.dr.zone_id }
output "dr_alb_arn" { value = aws_lb.dr.arn }
output "dr_ecs_cluster_name" { value = aws_ecs_cluster.dr.name }
output "dr_ecs_service_names" {
  value = { for k, v in aws_ecs_service.dr : k => v.name }
}
output "dr_acm_certificate_arn" { value = aws_acm_certificate_validation.dr.certificate_arn }

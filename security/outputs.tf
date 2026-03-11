output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.existing.zone_id
}

output "route53_name_servers" {
  description = "Route53 name servers"
  value       = data.aws_route53_zone.existing.name_servers
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = data.aws_acm_certificate.existing.arn
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : ""
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : ""
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = var.enable_cognito ? aws_cognito_user_pool.main[0].id : ""
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = var.enable_cognito ? aws_cognito_user_pool.main[0].arn : ""
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = var.enable_cognito ? aws_cognito_user_pool_client.main[0].id : ""
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = var.enable_cognito ? aws_cognito_user_pool.main[0].endpoint : ""
}

output "cognito_domain" {
  description = "Cognito domain"
  value       = var.enable_cognito ? aws_cognito_user_pool_domain.main[0].domain : ""
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = var.enable_cognito ? aws_cognito_identity_pool.main[0].id : ""
}

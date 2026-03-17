output "ecr_repository_urls" {
  description = "ECR repository URLs for all services"
  value = {
    for service in var.services :
    service => aws_ecr_repository.services[service].repository_url
  }
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs for all services"
  value = {
    for service in var.services :
    service => aws_ecr_repository.services[service].arn
  }
}

output "ecr_repository_names" {
  description = "ECR repository names for all services"
  value = {
    for service in var.services :
    service => aws_ecr_repository.services[service].name
  }
}

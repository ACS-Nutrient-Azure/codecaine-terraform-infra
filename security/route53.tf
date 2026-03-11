# ============================================================================
# 기존 Route53 Hosted Zone 참조 (Data Source)
# ============================================================================
# 이미 AWS에 존재하는 Route53 Hosted Zone을 Zone ID로 직접 참조합니다.
# Zone ID: Z009220527NRWAL7GBEUE

data "aws_route53_zone" "existing" {
  provider = aws.route53

  zone_id      = "Z009220527NRWAL7GBEUE"
  private_zone = false
}

# Zone ID 로컬 변수
locals {
  zone_id = data.aws_route53_zone.existing.zone_id
}

# ============================================================================
# 아래는 신규 생성 코드 (주석 처리)
# ============================================================================
# 기존 리소스가 있으므로 생성하지 않습니다.

# # Route53 Hosted Zone
# # 신규 생성: create_route53_zone = true
# # 기존 사용: create_route53_zone = false + route53_zone_id 입력
# resource "aws_route53_zone" "main" {
#   count = var.create_route53_zone ? 1 : 0
# 
#   provider = aws.route53
# 
#   name = var.domain_name
# 
#   tags = {
#     Name = "${upper(var.project_name)}-${upper(var.environment)}-ROUTE53-ZONE"
#   }
# }
# 
# # Data source for existing Route53 Hosted Zone (기존 Zone 사용 시)
# data "aws_route53_zone" "existing" {
#   count    = var.create_route53_zone ? 0 : 1
#   provider = aws.route53
# 
#   zone_id = var.route53_zone_id != "" ? var.route53_zone_id : null
#   name = var.route53_zone_id == "" ? "${var.domain_name}." : null
# 
#   private_zone = false
# }
# 
# # Zone ID 결정 로직
# locals {
#   zone_id = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
# }
# 
# # Zone ID validation
# resource "null_resource" "validate_zone_id" {
#   lifecycle {
#     precondition {
#       condition     = var.create_route53_zone || var.route53_zone_id != ""
#       error_message = "route53_zone_id must be provided when create_route53_zone is false. Please set route53_zone_id in terraform.tfvars"
#     }
#   }
# }

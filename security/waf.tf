# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0

  name  = upper("${var.project_name}-${var.environment}-WAF")
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rate Limiting Rule
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  # Geo Blocking (선택)
  rule {
    name     = "GeoBlockRule"
    priority = 4

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = ["CN", "RU"] # 차단할 국가 코드
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = upper("${var.project_name}-${var.environment}-WAF-METRIC")
    sampled_requests_enabled   = true
  }

  tags = {
    Name = upper("${var.project_name}-${var.environment}-WAF")
  }
}

# WAF Logging Configuration
resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_waf ? 1 : 0

  name              = "aws-waf-logs-${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name = upper("${var.project_name}-${var.environment}-WAF-LOGS")
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enable_waf ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
}

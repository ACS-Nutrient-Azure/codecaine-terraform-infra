terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key     = "fis/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "fis"
    }
  }
}

data "aws_caller_identity" "current" {}

# ── Remote State ─────────────────────────────────────────────────

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "foundation/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "terraform-tfstate-620758375333-ap-northeast-2-an"
    key    = "compute/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# stop_condition_alarm_arn이 비어있으면 더미 알람 생성
# DR 알람(cdci-prd-DR-TRIGGER)이 없는 상태에서도 FIS 실험 실행 가능
resource "aws_cloudwatch_metric_alarm" "fis_stop_condition_dummy" {
  count = var.stop_condition_alarm_arn == "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-fis-stop-condition"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FISDummyMetric"
  namespace           = "${var.project_name}/FIS"
  period              = 60
  statistic           = "Sum"
  threshold           = 9999999
  treat_missing_data  = "notBreaching"
  alarm_description   = "FIS stop condition dummy alarm - never fires unless manually set"
}

locals {
  stop_condition_alarm_arn = var.stop_condition_alarm_arn != "" ? var.stop_condition_alarm_arn : aws_cloudwatch_metric_alarm.fis_stop_condition_dummy[0].arn
}

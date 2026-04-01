# ============================================================
# AWS Managed Grafana - IAM Role
# ============================================================
resource "aws_iam_role" "grafana" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-GRAFANA-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "grafana.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "grafana_datasources" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-GRAFANA-DATASOURCES-POLICY"
  role = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Metrics + Logs (ECS, ALB, RDS, ElastiCache 등)
      {
        Sid    = "CloudWatchAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = "*"
      },
      # CloudWatch Logs Insights (서비스 로그 쿼리)
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogGroupFields",
          "logs:GetLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      # X-Ray Traces (ADOT → X-Ray)
      {
        Sid    = "XRayAccess"
        Effect = "Allow"
        Action = [
          "xray:GetTraceSummaries",
          "xray:GetServiceGraph",
          "xray:GetTraceGraph",
          "xray:BatchGetTraces",
          "xray:GetInsights",
          "xray:GetInsightSummaries",
          "xray:GetInsightImpactGraph",
          "xray:GetGroups",
          "xray:GetGroup"
        ]
        Resource = "*"
      },
      # EC2 (인스턴스/태그 정보 조회용)
      {
        Sid    = "EC2ReadAccess"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================
# AWS Managed Grafana - Workspace
# ============================================================
resource "aws_grafana_workspace" "main" {
  name                     = "${var.project_name}-${var.environment}-grafana"
  description              = "Codecaine ${upper(var.environment)} - Unified Observability Dashboard"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  data_sources = [
    "CLOUDWATCH",
    "XRAY"
  ]

  # CloudWatch 알림을 Grafana에서 관리하려면 활성화
  notification_destinations = ["SNS"]

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-GRAFANA"
  }
}

# ============================================================
# Grafana SSO Role Association (Admin 그룹 접근 허용)
# ============================================================
resource "aws_grafana_role_association" "admins" {
  count        = length(var.grafana_admin_groups) > 0 ? 1 : 0
  role         = "ADMIN"
  group_ids    = var.grafana_admin_groups
  workspace_id = aws_grafana_workspace.main.id
}

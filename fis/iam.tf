# ── FIS IAM Role ─────────────────────────────────────────────────
# FIS가 실험 액션을 수행하기 위한 서비스 역할

resource "aws_iam_role" "fis" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-FIS-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "fis.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

# ECS 액션 권한 (태스크 중지, 서비스 중단)
resource "aws_iam_role_policy" "fis_ecs" {
  name = "fis-ecs-policy"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSActions"
        Effect = "Allow"
        Action = [
          "ecs:StopTask",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
      }
    ]
  })
}

# RDS / Aurora 액션 권한 (재부팅, 페일오버)
resource "aws_iam_role_policy" "fis_rds" {
  name = "fis-rds-policy"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSActions"
        Effect = "Allow"
        Action = [
          "rds:RebootDBInstance",
          "rds:FailoverDBCluster",
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# ElastiCache 액션 권한 (재부팅)
resource "aws_iam_role_policy" "fis_elasticache" {
  name = "fis-elasticache-policy"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ElastiCacheActions"
        Effect = "Allow"
        Action = [
          "elasticache:RebootCacheCluster",
          "elasticache:DescribeCacheClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# 네트워크 장애 주입 (VPC, 서브넷, 보안그룹, NACL)
resource "aws_iam_role_policy" "fis_network" {
  name = "fis-network-policy"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "NetworkActions"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkAcl",
          "ec2:CreateNetworkAclEntry",
          "ec2:DeleteNetworkAcl",
          "ec2:DeleteNetworkAclEntry",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeNetworkAclAssociations",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:ReplaceNetworkAclAssociation",
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:StartInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch 로그 기록 권한
resource "aws_iam_role_policy" "fis_logs" {
  name = "fis-logs-policy"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# SSM (EC2 Bastion 네트워크 장애 주입용)
resource "aws_iam_role_policy" "fis_ssm" {
  name = "fis-ssm-policy"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMActions"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
      }
    ]
  })
}

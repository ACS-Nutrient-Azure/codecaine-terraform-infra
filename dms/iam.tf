# ============================================================
# DMS IAM 역할
# ============================================================

# DMS가 VPC 내 리소스 접근 시 필요한 역할 (이름 고정 필수)
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "dms-vpc-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# DMS CloudWatch 로그 역할 (이름 고정 필수)
resource "aws_iam_role" "dms_cloudwatch_role" {
  name = "dms-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "dms-cloudwatch-logs-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_role" {
  role       = aws_iam_role.dms_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# DMS Task용 IAM 역할 (Secrets Manager 접근)
resource "aws_iam_role" "dms_task_role" {
  name = "${local.name_prefix}-dms-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-dms-task-role"
  }
}

resource "aws_iam_role_policy" "dms_task_secrets" {
  name = "${local.name_prefix}-dms-task-secrets-policy"
  role = aws_iam_role.dms_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        data.aws_secretsmanager_secret_version.users_cluster.arn,
        data.aws_secretsmanager_secret_version.analysis_cluster.arn,
      ]
    }]
  })
}

# DMS Full Load S3 임시 버퍼 접근 권한
resource "aws_iam_role_policy" "dms_task_s3" {
  name = "${local.name_prefix}-dms-task-s3-policy"
  role = aws_iam_role.dms_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      }
    ]
  })
}

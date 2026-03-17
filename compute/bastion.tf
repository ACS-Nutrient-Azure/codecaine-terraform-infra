# Bastion Host Security Group
resource "aws_security_group" "bastion" {
  name_prefix = lower("${var.project_name}-${var.environment}-bastion-")
  description = "Security group for Bastion host"
  vpc_id      = local.vpc_id

  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-BASTION-SG"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Bastion Host IAM Role
resource "aws_iam_role" "bastion" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-BASTION-ROLE"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-BASTION-ROLE"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${upper(var.project_name)}-${upper(var.environment)}-BASTION-PROFILE"
  role = aws_iam_role.bastion.name
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Bastion Host Instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.bastion_instance_type
  key_name               = var.bastion_key_name # 기존 키 페어 사용 (tera-test.pem)
  subnet_id              = local.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y postgresql15
              EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-BASTION"
  }
}

# Elastic IP for Bastion
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-BASTION-EIP"
  }
}

# RDS 보안 그룹에 Bastion 접근 허용 규칙 추가
resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = local.rds_security_group_id
  description              = "PostgreSQL from Bastion host"
}

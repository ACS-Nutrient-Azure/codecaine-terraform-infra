# VPC Configuration (독립 실행 가능)
# 기존 VPC를 사용하려면 use_existing_vpc = true로 설정

locals {
  # 기존 VPC 사용 여부에 따라 리소스 선택
  vpc_id                      = var.use_existing_vpc ? data.terraform_remote_state.foundation[0].outputs.vpc_id : aws_vpc.cluster[0].id
  public_subnet_ids           = var.use_existing_vpc ? data.terraform_remote_state.foundation[0].outputs.public_subnet_ids : aws_subnet.public[*].id
  private_app_subnet_ids      = var.use_existing_vpc ? data.terraform_remote_state.foundation[0].outputs.private_app_subnet_ids : aws_subnet.private_app[*].id
  alb_security_group_id       = var.use_existing_vpc ? data.terraform_remote_state.foundation[0].outputs.alb_security_group_id : aws_security_group.alb[0].id
  ecs_tasks_security_group_id = var.use_existing_vpc ? data.terraform_remote_state.foundation[0].outputs.ecs_tasks_security_group_id : aws_security_group.ecs_tasks[0].id
}

# VPC (독립 모드)
resource "aws_vpc" "cluster" {
  count = var.use_existing_vpc ? 0 : 1

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "cluster" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.cluster[0].id

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = var.use_existing_vpc ? 0 : length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.cluster[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-public-subnet-${count.index + 1}"
  }
}

# Private Application Subnets
resource "aws_subnet" "private_app" {
  count = var.use_existing_vpc ? 0 : length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.cluster[0].id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-private-subnet-${count.index + 1}"
  }
}

# NAT Gateway (독립 모드)
resource "aws_eip" "nat" {
  count = var.use_existing_vpc ? 0 : (var.enable_nat_gateway ? length(var.availability_zones) : 0)

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "cluster" {
  count = var.use_existing_vpc ? 0 : (var.enable_nat_gateway ? length(var.availability_zones) : 0)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.cluster]
}

# Public Route Table
resource "aws_route_table" "public" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.cluster[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster[0].id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = var.use_existing_vpc ? 0 : length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private Route Tables
resource "aws_route_table" "private_app" {
  count = var.use_existing_vpc ? 0 : length(var.availability_zones)

  vpc_id = aws_vpc.cluster[0].id

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-private-rt-${count.index + 1}"
  }
}

resource "aws_route" "private_nat" {
  count = var.use_existing_vpc ? 0 : (var.enable_nat_gateway ? length(var.availability_zones) : 0)

  route_table_id         = aws_route_table.private_app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.cluster[count.index].id
}

resource "aws_route_table_association" "private_app" {
  count = var.use_existing_vpc ? 0 : length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# Security Groups (독립 모드)
resource "aws_security_group" "alb" {
  count = var.use_existing_vpc ? 0 : 1

  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.cluster[0].id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs_tasks" {
  count = var.use_existing_vpc ? 0 : 1

  name_prefix = "${var.project_name}-${var.environment}-ecs-tasks-"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.cluster[0].id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
  }

  ingress {
    description = "Allow inter-service communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

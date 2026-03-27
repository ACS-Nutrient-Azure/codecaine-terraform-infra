resource "aws_vpc" "dr" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-VPC" }
}

resource "aws_internet_gateway" "dr" {
  vpc_id = aws_vpc.dr.id
  tags   = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-IGW" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.dr.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-PUBLIC-${upper(substr(var.availability_zones[count.index], -2, 2))}"
  }
}

resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.dr.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-PRIVATE-APP-${upper(substr(var.availability_zones[count.index], -2, 2))}"
  }
}

resource "aws_subnet" "private_db" {
  count             = length(var.private_db_subnet_cidrs)
  vpc_id            = aws_vpc.dr.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-PRIVATE-DB-${upper(substr(var.availability_zones[count.index], -2, 2))}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.dr.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr.id
  }
  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-PUBLIC-RT" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.dr.id
  tags   = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-PRIVATE-APP-RT" }
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.dr.id
  tags   = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-PRIVATE-DB-RT" }
}

resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_db_subnet_group" "dr" {
  name       = lower("${var.project_name}-${var.environment}-dr-db-subnet-group")
  subnet_ids = aws_subnet.private_db[*].id
  tags       = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-DB-SUBNET-GROUP" }
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-dr-alb-sg"
  description = "DR ALB security group"
  vpc_id      = aws_vpc.dr.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ALB-SG" }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment}-dr-ecs-tasks-sg"
  description = "DR ECS tasks security group"
  vpc_id      = aws_vpc.dr.id

  ingress {
    from_port       = 8000
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-ECS-TASKS-SG" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-dr-rds-sg"
  description = "DR RDS security group"
  vpc_id      = aws_vpc.dr.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-RDS-SG" }
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-dr-redis-sg"
  description = "DR Redis security group"
  vpc_id      = aws_vpc.dr.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${upper(var.project_name)}-${upper(var.environment)}-DR-REDIS-SG" }
}

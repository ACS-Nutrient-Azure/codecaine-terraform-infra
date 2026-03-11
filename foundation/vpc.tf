# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-IGW"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-VPC-PUBLIC-${upper(substr(var.availability_zones[count.index], -2, 2))}"
    Type = "Public"
  }
}

# Private Application Subnets (for ECS tasks)
resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-VPC-PRIVATE-APP-${upper(substr(var.availability_zones[count.index], -2, 2))}"
    Type = "PrivateApp"
  }
}

# Private Database Subnets
resource "aws_subnet" "private_db" {
  count             = length(var.private_db_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-VPC-PRIVATE-DB-${upper(substr(var.availability_zones[count.index], -2, 2))}"
    Type = "PrivateDB"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-PUBLIC-RT"
  }
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private App Route Table (single for all AZs with single NAT Gateway)
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-PRIVATE-APP-RT"
  }
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

# Database Route Table
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-PRIVATE-DB-RT"
  }
}

resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = lower("${var.project_name}-${var.environment}-db-subnet-group")
  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-DB-SUBNET-GROUP"
  }
}

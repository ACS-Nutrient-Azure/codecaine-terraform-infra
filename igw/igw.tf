resource "aws_internet_gateway" "main" {
  vpc_id = data.terraform_remote_state.common.outputs.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = data.terraform_remote_state.common.outputs.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(data.terraform_remote_state.common.outputs.public_subnet_ids)
  subnet_id      = data.terraform_remote_state.common.outputs.public_subnet_ids[count.index]
  route_table_id = aws_route_table.public.id
}

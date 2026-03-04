resource "aws_eip" "nat" {
  count  = var.nat_gateway_count
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  count         = var.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = data.terraform_remote_state.common.outputs.public_subnet_ids[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  count  = var.nat_gateway_count
  vpc_id = data.terraform_remote_state.common.outputs.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  count          = length(data.terraform_remote_state.common.outputs.private_subnet_ids)
  subnet_id      = data.terraform_remote_state.common.outputs.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private[count.index % var.nat_gateway_count].id
}

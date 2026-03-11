# Elastic IP for NAT Gateway (single per region)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-NAT-EIP"
  }

  depends_on = [data.terraform_remote_state.foundation]
}

# NAT Gateway (single per region for cost optimization)
# connectivity_type: public (regional NAT) vs private (zonal NAT for VPC-to-VPC)
resource "aws_nat_gateway" "main" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = data.terraform_remote_state.foundation.outputs.public_subnet_ids[0]
  connectivity_type = "public"

  tags = {
    Name = "${upper(var.project_name)}-${upper(var.environment)}-NAT-GW"
  }

  depends_on = [aws_eip.nat]
}

# Update Private App Route Table to use NAT Gateway
resource "aws_route" "private_app_nat" {
  route_table_id         = data.terraform_remote_state.foundation.outputs.private_app_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

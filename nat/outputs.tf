output "nat_gateway_ids" {
  value = aws_nat_gateway.main[*].id
}

output "nat_eip_addresses" {
  value = aws_eip.nat[*].public_ip
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

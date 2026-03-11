output "nat_gateway_id" {
  description = "NAT Gateway ID (single per region)"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP (single per region)"
  value       = aws_eip.nat.public_ip
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "The three availability zones selected for this VPC."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of public subnets."
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "IDs of private subnets."
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets."
  value       = aws_subnet.private[*].cidr_block
}

output "internet_gateway_id" {
  description = "ID of the internet gateway, if created."
  value       = try(aws_internet_gateway.this[0].id, null)
}

output "nat_gateway_ids" {
  description = "IDs of NAT gateways, if enabled."
  value       = aws_nat_gateway.this[*].id
}

output "public_route_table_ids" {
  description = "IDs of public route tables."
  value       = [for rt in aws_route_table.public : rt.id]
}

output "private_route_table_ids" {
  description = "IDs of private route tables."
  value       = [for rt in aws_route_table.private : rt.id]
}

output "gateway_vpc_endpoint_ids" {
  description = "IDs of gateway VPC endpoints."
  value       = { for service, endpoint in aws_vpc_endpoint.gateway : service => endpoint.id }
}

output "interface_vpc_endpoint_ids" {
  description = "IDs of interface VPC endpoints."
  value       = { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.id }
}

output "flow_log_id" {
  description = "ID of the VPC flow log, if enabled."
  value       = try(aws_flow_log.this[0].id, null)
}

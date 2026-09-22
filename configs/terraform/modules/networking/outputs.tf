output "vpc_id" {
description = "VPC ID."
value       = aws_vpc.this.id
}

output "vpc_cidr" {
description = "VPC CIDR block."
value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
description = "IDs of public subnets."
value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
description = "IDs of private application subnets."
value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
description = "IDs of database subnets."
value       = aws_subnet.database[*].id
}

output "nat_gateway_ids" {
description = "IDs of NAT gateways."
value       = aws_nat_gateway.this[*].id
}

output "internet_gateway_id" {
description = "Internet Gateway ID."
value       = aws_internet_gateway.this.id
}

output "public_route_table_id" {
description = "Public route table ID."
value       = aws_route_table.public.id
}

output "private_route_table_ids" {
description = "Private route table IDs."
value       = aws_route_table.private[*].id
}

output "database_route_table_ids" {
description = "Database route table IDs."
value       = aws_route_table.database[*].id
}

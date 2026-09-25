
output "replication_group_id" {
  description = "Redis replication group ID."
  value       = aws_elasticache_replication_group.this.id
}

output "replication_group_arn" {
  description = "Redis replication group ARN."
  value       = aws_elasticache_replication_group.this.arn
}

output "primary_endpoint_address" {
  description = "Redis primary endpoint address."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Redis reader endpoint address."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Redis port."
  value       = aws_elasticache_replication_group.this.port
}

output "member_clusters" {
  description = "Redis member cluster identifiers."
  value       = aws_elasticache_replication_group.this.member_clusters
}

output "subnet_group_name" {
  description = "Redis subnet group name."
  value       = aws_elasticache_subnet_group.this.name
}



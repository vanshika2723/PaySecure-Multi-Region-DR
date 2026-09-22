
output "cluster_id" {
  description = "Aurora cluster ID."
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "Aurora cluster ARN."
  value       = aws_rds_cluster.this.arn
}

output "cluster_identifier" {
  description = "Aurora cluster identifier."
  value       = aws_rds_cluster.this.cluster_identifier
}

output "cluster_endpoint" {
  description = "Aurora writer endpoint."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Aurora reader endpoint."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  description = "Aurora PostgreSQL port."
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "Aurora database name."
  value       = aws_rds_cluster.this.database_name
}

output "engine" {
  description = "Aurora database engine."
  value       = aws_rds_cluster.this.engine
}

output "engine_version" {
  description = "Aurora database engine version."
  value       = aws_rds_cluster.this.engine_version
}

output "instance_ids" {
  description = "Aurora DB instance IDs."
  value       = aws_rds_cluster_instance.this[*].id
}

output "instance_arns" {
  description = "Aurora DB instance ARNs."
  value       = aws_rds_cluster_instance.this[*].arn
}

output "subnet_group_name" {
  description = "Aurora DB subnet group name."
  value       = aws_db_subnet_group.this.name
}


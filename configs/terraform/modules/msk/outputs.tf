output "cluster_arn" {
  description = "MSK cluster ARN."
  value       = aws_msk_cluster.this.arn
}

output "cluster_name" {
  description = "MSK cluster name."
  value       = aws_msk_cluster.this.cluster_name
}

output "cluster_uuid" {
  description = "MSK cluster UUID."
  value       = aws_msk_cluster.this.cluster_uuid
}

output "bootstrap_brokers" {
  description = "MSK plaintext bootstrap brokers."
  value       = aws_msk_cluster.this.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "MSK TLS bootstrap brokers."
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "zookeeper_connect_string" {
  description = "MSK ZooKeeper connection string."
  value       = aws_msk_cluster.this.zookeeper_connect_string
}

output "current_version" {
  description = "Current MSK cluster version."
  value       = aws_msk_cluster.this.current_version
}


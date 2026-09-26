
resource "aws_rds_global_cluster" "paysecure" {
  count = var.enable_aurora_global ? 1 : 0

  provider = aws.primary

  global_cluster_identifier = "${var.project_name}-global"

  source_db_cluster_identifier = module.primary_aurora[0].cluster_arn

  engine = var.aurora_engine
  engine_version = var.aurora_engine_version

  database_name = var.aurora_database_name

  storage_encrypted = true
  deletion_protection = true

  force_destroy = false

  tags = merge(local.common_tags, {
    Name   = "${var.project_name}-aurora-global"
    Purpose = "Cross-region payment database replication"
  })
}

output "aurora_global_cluster_arn" {
  description = "Aurora Global Database ARN."
  value = try(aws_rds_global_cluster.paysecure[0].arn, null)
}

output "aurora_global_cluster_endpoint" {
  description = "Aurora Global Database writer endpoint."
  value = try(aws_rds_global_cluster.paysecure[0].endpoint, null)
}






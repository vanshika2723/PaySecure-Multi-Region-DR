resource "aws_elasticache_global_replication_group" "paysecure" {
  count = var.enable_redis_global ? 1 : 0

  provider = aws.primary

  global_replication_group_id_suffix = "${var.project_name}-global"

  primary_replication_group_id = module.primary_redis[0].replication_group_id

  automatic_failover_enabled = true

  cache_node_type = var.redis_node_type

  engine = "REDIS"

  engine_version = var.redis_engine_version

  transit_encryption_enabled = true

  at_rest_encryption_enabled = true

  tags = merge(local.common_tags, {
    Name   = "${var.project_name}-redis-global"
    Purpose = "Cross-region cache replication"
  })
}

output "redis_global_replication_group_id" {
  description = "Redis Global Datastore replication group ID."
  value = try(
    aws_elasticache_global_replication_group.paysecure[0].global_replication_group_id,
    null
  )
}
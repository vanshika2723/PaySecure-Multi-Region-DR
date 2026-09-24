
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.replication_group_id}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.replication_group_id}-subnet-group"
    }
  )
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.replication_group_id
  description          = var.description

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  num_cache_clusters = var.num_cache_clusters

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  automatic_failover_enabled = true
  multi_az_enabled            = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  kms_key_id = var.kms_key_id

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window

  maintenance_window = var.maintenance_window

  apply_immediately = var.apply_immediately

  tags = var.common_tags
}


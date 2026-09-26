
resource "aws_rds_cluster" "this" {
  cluster_identifier = var.cluster_identifier

  engine         = var.engine
  engine_version = var.engine_version
  database_name  = var.database_name

  master_username = var.master_username
  master_password = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  storage_encrypted = true
  kms_key_id        = var.kms_key_id

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  copy_tags_to_snapshot = true

  enabled_cloudwatch_logs_exports = [
    "postgresql"
  ]

  tags = var.common_tags
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id

  instance_class = var.instance_class
  engine         = aws_rds_cluster.this.engine

  publicly_accessible = false

  auto_minor_version_upgrade = true

  performance_insights_enabled = var.performance_insights_enabled

  monitoring_interval = var.monitoring_interval

  tags = var.common_tags
}

resource "aws_db_subnet_group" "this" {
  name = "${var.cluster_identifier}-subnet-group"

  subnet_ids = var.subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_identifier}-subnet-group"
    }
  )
}

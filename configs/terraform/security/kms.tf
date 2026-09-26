
resource "aws_kms_key" "primary" {
  provider = aws.primary

  description             = "PaySecure primary region encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-primary-kms"
    Purpose     = "Multi-region DR encryption"
    RegionRole  = "primary"
  })
}

resource "aws_kms_alias" "primary" {
  provider = aws.primary

  name          = "alias/${var.project_name}-primary"
  target_key_id = aws_kms_key.primary.key_id
}

resource "aws_kms_replica_key" "dr" {
  provider = aws.dr

  primary_key_arn = aws_kms_key.primary.arn

  description = "PaySecure DR region replica encryption key"

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-dr-kms"
    Purpose    = "Multi-region DR encryption"
    RegionRole = "dr"
  })
}

resource "aws_kms_alias" "dr" {
  provider = aws.dr

  name          = "alias/${var.project_name}-dr"
  target_key_id = aws_kms_replica_key.dr.key_id
}

output "primary_kms_key_arn" {
  description = "Primary KMS key ARN."
  value       = aws_kms_key.primary.arn
}

output "dr_kms_key_arn" {
  description = "DR KMS replica key ARN."
  value       = aws_kms_replica_key.dr.arn
}




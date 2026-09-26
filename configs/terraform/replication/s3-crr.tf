resource "aws_s3_bucket" "primary_dr_artifacts" {
  count = var.enable_s3_crr ? 1 : 0

  provider = aws.primary

  bucket = "${var.project_name}-dr-artifacts-primary"

  tags = merge(local.common_tags, {
    Name   = "${var.project_name}-dr-artifacts-primary"
    Region = var.primary_region
  })
}

resource "aws_s3_bucket" "dr_artifacts" {
  count = var.enable_s3_crr ? 1 : 0

  provider = aws.dr

  bucket = "${var.project_name}-dr-artifacts-secondary"

  tags = merge(local.common_tags, {
    Name   = "${var.project_name}-dr-artifacts-secondary"
    Region = var.dr_region
  })
}

resource "aws_s3_bucket_versioning" "primary" {
  count = var.enable_s3_crr ? 1 : 0

  provider = aws.primary

  bucket = aws_s3_bucket.primary_dr_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "dr" {
  count = var.enable_s3_crr ? 1 : 0

  provider = aws.dr

  bucket = aws_s3_bucket.dr_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_replication_configuration" "primary_to_dr" {
  count = var.enable_s3_crr ? 1 : 0

  provider = aws.primary

  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.dr
  ]

  bucket = aws_s3_bucket.primary_dr_artifacts[0].id

 role = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-dr-artifacts"
    status = "Enabled"

    destination {
      bucket = aws_s3_bucket.dr_artifacts[0].arn

      storage_class = "STANDARD"
    }
  }
}

output "primary_dr_artifacts_bucket" {
  description = "Primary DR artifacts bucket."
  value = try(aws_s3_bucket.primary_dr_artifacts[0].id, null)
}

output "secondary_dr_artifacts_bucket" {
  description = "Secondary DR artifacts bucket."
  value = try(aws_s3_bucket.dr_artifacts[0].id, null)
}

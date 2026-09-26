
data "aws_caller_identity" "current" {
  provider = aws.primary
}

data "aws_partition" "current" {
  provider = aws.primary
}

# ---------------------------------------------------------
# S3 Cross-Region Replication Role
# ---------------------------------------------------------

data "aws_iam_policy_document" "s3_replication_assume_role" {
  statement {
    sid     = "S3ReplicationTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "s3_replication" {
  provider = aws.primary

  name = "${var.project_name}-s3-replication"

  assume_role_policy = data.aws_iam_policy_document.s3_replication_assume_role.json

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-s3-replication"
    Purpose = "S3 Cross-Region Replication"
  })
}

data "aws_iam_policy_document" "s3_replication" {
  statement {
    sid    = "ReadSourceBucket"
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.primary_dr_artifacts[0].arn
    ]
  }

  statement {
    sid    = "ReadSourceObjects"
    effect = "Allow"

    actions = [
      "s3:GetObjectVersion",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging"
    ]

    resources = [
      "${aws_s3_bucket.primary_dr_artifacts[0].arn}/*"
    ]
  }

  statement {
    sid    = "ReplicateObjects"
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags"
    ]

    resources = [
      "${aws_s3_bucket.dr_artifacts[0].arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "s3_replication" {
  provider = aws.primary

  count = var.enable_s3_crr ? 1 : 0

  name = "${var.project_name}-s3-replication-policy"
  role = aws_iam_role.s3_replication.id

  policy = data.aws_iam_policy_document.s3_replication.json
}

# ---------------------------------------------------------
# MSK Replicator IAM Role
# ---------------------------------------------------------

data "aws_iam_policy_document" "msk_replicator_assume_role" {
  statement {
    sid     = "MSKReplicatorTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["kafka.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "msk_replicator" {
  provider = aws.primary

  name = "${var.project_name}-msk-replicator"

  assume_role_policy = data.aws_iam_policy_document.msk_replicator_assume_role.json

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-msk-replicator"
    Purpose = "MSK cross-region replication"
  })
}

data "aws_iam_policy_document" "msk_replicator" {
  statement {
    sid    = "MSKDescribe"
    effect = "Allow"

    actions = [
      "kafka:DescribeCluster",
      "kafka:GetBootstrapBrokers",
      "kafka:ListClusters"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "MSKNetwork"
    effect = "Allow"

    actions = [
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
      "ec2:DescribeRouteTables",
      "ec2:DescribeNetworkInterfaces"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "MSKReplication"
    effect = "Allow"

    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:ReadData",
      "kafka-cluster:WriteData",
      "kafka-cluster:DescribeGroup",
      "kafka-cluster:AlterGroup"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "msk_replicator" {
  provider = aws.primary

  count = var.enable_msk_replicator ? 1 : 0

  name = "${var.project_name}-msk-replicator-policy"
  role = aws_iam_role.msk_replicator.id

  policy = data.aws_iam_policy_document.msk_replicator.json
}

# ---------------------------------------------------------
# Outputs
# ---------------------------------------------------------

output "s3_replication_role_arn" {
  description = "IAM role ARN for S3 Cross-Region Replication."
  value       = aws_iam_role.s3_replication.arn
}

output "msk_replicator_role_arn" {
  description = "IAM role ARN for MSK Replicator."
  value       = aws_iam_role.msk_replicator.arn
}





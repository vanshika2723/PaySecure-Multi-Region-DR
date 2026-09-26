resource "aws_msk_replicator" "paysecure" {
  count = var.enable_msk_replicator ? 1 : 0

  provider = aws.primary

  replicator_name = "${var.project_name}-replicator"

  description = "PaySecure Mumbai to Hyderabad MSK replication"

  service_execution_role_arn = var.msk_replicator_role_arn

  kafka_cluster {
    amazon_msk_cluster {
      msk_cluster_arn = module.primary_msk[0].cluster_arn
    }

    vpc_config {
      subnet_ids = module.primary_networking.private_subnet_ids

      security_group_ids = [
        aws_security_group.primary_kafka.id
      ]
    }
  }

  target_kafka_cluster {
    amazon_msk_cluster {
      msk_cluster_arn = module.dr_msk[0].cluster_arn
    }

    vpc_config {
      subnet_ids = module.dr_networking.private_subnet_ids

      security_group_ids = [
        aws_security_group.dr_kafka.id
      ]
    }
  }

  replication_info_list {
    consumer_group_replication {
      enabled = true
    }

    topic_replication {
      enabled = true

      topics_to_replicate = [
        "payments",
        "transactions",
        "settlements",
        "notifications"
      ]
    }
  }

  tags = merge(local.common_tags, {
    Name   = "${var.project_name}-msk-replicator"
    Purpose = "Cross-region Kafka replication"
  })
}

output "msk_replicator_arn" {
  description = "MSK Replicator ARN."
  value = try(aws_msk_replicator.paysecure[0].arn, null)
}
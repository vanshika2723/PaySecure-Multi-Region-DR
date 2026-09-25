variable "cluster_name" {
  description = "Amazon MSK cluster name."
  type        = string
}

variable "kafka_version" {
  description = "Apache Kafka version."
  type        = string
  default     = "3.8.x"
}

variable "number_of_broker_nodes" {
  description = "Number of Kafka broker nodes."
  type        = number
  default     = 3

  validation {
    condition     = var.number_of_broker_nodes >= 3
    error_message = "MSK requires at least three broker nodes for this architecture."
  }
}

variable "instance_type" {
  description = "MSK broker instance type."
  type        = string
  default     = "kafka.m5.large"
}

variable "subnet_ids" {
  description = "Private subnet IDs used by MSK brokers."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 3
    error_message = "MSK requires at least three subnets for this architecture."
  }
}

variable "security_group_ids" {
  description = "Security groups attached to MSK brokers."
  type        = list(string)
}

variable "volume_size" {
  description = "EBS volume size per MSK broker in GiB."
  type        = number
  default     = 500

  validation {
    condition     = var.volume_size >= 100
    error_message = "MSK broker storage must be at least 100 GiB."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN used for MSK encryption at rest."
  type        = string
}

variable "enhanced_monitoring" {
  description = "MSK enhanced monitoring level."
  type        = string
  default     = "PER_BROKER"

  validation {
    condition = contains(
      [
        "DEFAULT",
        "PER_BROKER",
        "PER_TOPIC_PER_BROKER",
        "PER_TOPIC_PER_PARTITION"
      ],
      var.enhanced_monitoring
    )

    error_message = "Invalid MSK enhanced monitoring level."
  }
}

variable "cloudwatch_logs_enabled" {
  description = "Enable MSK broker logs in CloudWatch."
  type        = bool
  default     = true
}

variable "cloudwatch_log_group" {
  description = "CloudWatch log group for MSK broker logs."
  type        = string
  default     = "/aws/msk/paysecure"
}

variable "common_tags" {
  description = "Common tags applied to MSK resources."
  type        = map(string)
  default     = {}
}

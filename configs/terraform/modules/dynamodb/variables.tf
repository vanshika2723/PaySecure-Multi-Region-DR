
variable "table_name" {
  description = "DynamoDB table name."
  type        = string
}

variable "billing_mode" {
  description = "DynamoDB billing mode."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "hash_key" {
  description = "DynamoDB partition key attribute name."
  type        = string
  default     = "transaction_id"
}

variable "hash_key_type" {
  description = "DynamoDB partition key attribute type."
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "hash_key_type must be S, N, or B."
  }
}

variable "range_key" {
  description = "Optional DynamoDB sort key attribute name."
  type        = string
  default     = null
}

variable "range_key_type" {
  description = "DynamoDB sort key attribute type."
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "range_key_type must be S, N, or B."
  }
}

variable "replica_regions" {
  description = "AWS regions used for DynamoDB Global Table replication."
  type        = list(string)
  default     = ["ap-south-2"]
}

variable "kms_key_arn" {
  description = "KMS key ARN for DynamoDB server-side encryption."
  type        = string
  default     = null
}

variable "stream_enabled" {
  description = "Enable DynamoDB Streams."
  type        = bool
  default     = true
}

variable "stream_view_type" {
  description = "DynamoDB Streams view type."
  type        = string
  default     = "NEW_AND_OLD_IMAGES"

  validation {
    condition = contains(
      [
        "KEYS_ONLY",
        "NEW_IMAGE",
        "OLD_IMAGE",
        "NEW_AND_OLD_IMAGES"
      ],
      var.stream_view_type
    )

    error_message = "Invalid DynamoDB stream view type."
  }
}

variable "common_tags" {
  description = "Common tags applied to DynamoDB resources."
  type        = map(string)
  default     = {}
}



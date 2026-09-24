
variable "replication_group_id" {
  description = "Redis replication group identifier."
  type        = string
}

variable "description" {
  description = "Description of the Redis replication group."
  type        = string
  default     = "PaySecure DR Redis Global Datastore primary"
}

variable "engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.2"
}

variable "node_type" {
  description = "ElastiCache Redis node instance type."
  type        = string
  default     = "cache.r6g.large"
}

variable "num_cache_clusters" {
  description = "Number of cache nodes in the replication group."
  type        = number
  default     = 2

  validation {
    condition     = var.num_cache_clusters >= 2
    error_message = "Redis replication group must have at least two cache nodes."
  }
}

variable "subnet_ids" {
  description = "Private subnet IDs for Redis."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Redis requires at least two subnets."
  }
}

variable "security_group_ids" {
  description = "Security groups attached to Redis."
  type        = list(string)
}

variable "kms_key_id" {
  description = "KMS key ID or ARN used for Redis encryption."
  type        = string
  default     = null
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain Redis snapshots."
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Daily Redis snapshot window."
  type        = string
  default     = "18:30-19:30"
}

variable "maintenance_window" {
  description = "Weekly Redis maintenance window."
  type        = string
  default     = "sun:20:00-sun:21:00"
}

variable "apply_immediately" {
  description = "Apply Redis changes immediately."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags applied to Redis resources."
  type        = map(string)
  default     = {}
}

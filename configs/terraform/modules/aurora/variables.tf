 id="x4n2kd"`
variable "cluster_identifier" {
  description = "Aurora cluster identifier."
  type        = string
}

variable "engine" {
  description = "Aurora database engine."
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version."
  type        = string
  default     = "16.6"
}

variable "database_name" {
  description = "Initial database name."
  type        = string
  default     = "paysecure"
}

variable "master_username" {
  description = "Master database username."
  type        = string
  sensitive   = true
}

variable "master_password" {
  description = "Master database password."
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "Database subnet IDs for the Aurora cluster."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Aurora requires at least two database subnets."
  }
}

variable "vpc_security_group_ids" {
  description = "Security groups attached to the Aurora cluster."
  type        = list(string)
}

variable "kms_key_id" {
  description = "KMS key used for Aurora encryption."
  type        = string
  default     = null
}

variable "instance_class" {
  description = "Aurora DB instance class."
  type        = string
  default     = "db.r6g.large"
}

variable "instance_count" {
  description = "Number of Aurora instances."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1
    error_message = "Aurora must have at least one instance."
  }
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 1
    error_message = "Backup retention must be at least one day."
  }
}

variable "preferred_backup_window" {
  description = "Preferred automated backup window."
  type        = string
  default     = "18:00-18:30"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window."
  type        = string
  default     = "sun:19:00-sun:19:30"
}

variable "deletion_protection" {
  description = "Protect the Aurora cluster from accidental deletion."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying the cluster."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds. Set to 0 to disable."
  type        = number
  default     = 60

  validation {
    condition = contains(
      [0, 1, 5, 10, 15, 30, 60],
      var.monitoring_interval
    )
    error_message = "Monitoring interval must be one of 0, 1, 5, 10, 15, 30, or 60 seconds."
  }
}

variable "common_tags" {
  description = "Common tags applied to Aurora resources."
  type        = map(string)
  default     = {}
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID."
  type        = string
}

variable "zone_name" {
  description = "DNS zone name."
  type        = string
  default     = "paysecure.in"
}

variable "record_name" {
  description = "Application DNS record."
  type        = string
  default     = "api.paysecure.in"
}

variable "record_type" {
  description = "DNS record type."
  type        = string
  default     = "A"
}

variable "primary_region" {
  description = "Primary AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "dr_region" {
  description = "DR AWS region."
  type        = string
  default     = "ap-south-2"
}

variable "primary_endpoint" {
  description = "Primary ALB endpoint."
  type        = string
}

variable "dr_endpoint" {
  description = "DR ALB endpoint."
  type        = string
}

variable "primary_alias_zone_id" {
  description = "Route 53 alias hosted zone ID for the primary endpoint."
  type        = string
}

variable "dr_alias_zone_id" {
  description = "Route 53 alias hosted zone ID for the DR endpoint."
  type        = string
}

variable "enable_health_checks" {
  description = "Enable Route 53 health checks."
  type        = bool
  default     = true
}

variable "primary_health_check_fqdn" {
  description = "FQDN monitored for the primary health check."
  type        = string
  default     = "api.paysecure.in"
}

variable "dr_health_check_fqdn" {
  description = "FQDN monitored for the DR health check."
  type        = string
  default     = "api-dr.paysecure.in"
}

variable "health_check_port" {
  description = "Health check port."
  type        = number
  default     = 443
}

variable "health_check_type" {
  description = "Route 53 health check type."
  type        = string
  default     = "HTTPS"
}

variable "health_check_path" {
  description = "HTTP path used by the health check."
  type        = string
  default     = "/health/ready"
}

variable "health_check_interval" {
  description = "Route 53 health check interval in seconds."
  type        = number
  default     = 10

  validation {
    condition     = contains([10, 30], var.health_check_interval)
    error_message = "Health check interval must be 10 or 30 seconds."
  }
}

variable "failure_threshold" {
  description = "Number of consecutive failures before health check is unhealthy."
  type        = number
  default     = 3

  validation {
    condition     = var.failure_threshold >= 1 && var.failure_threshold <= 10
    error_message = "Failure threshold must be between 1 and 10."
  }
}

variable "common_tags" {
  description = "Common tags applied to Route 53 resources."
  type        = map(string)
  default     = {}
}

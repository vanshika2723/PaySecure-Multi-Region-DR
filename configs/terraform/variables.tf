
variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "paysecure-dr"
}

variable "primary_region" {
  description = "Primary AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "dr_region" {
  description = "Disaster recovery AWS region."
  type        = string
  default     = "ap-south-2"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "production"
}

# ============================================================
# NETWORKING
# ============================================================

variable "vpc_cidr_primary" {
  description = "Primary VPC CIDR."
  type        = string
  default     = "10.10.0.0/16"
}

variable "vpc_cidr_dr" {
  description = "DR VPC CIDR."
  type        = string
  default     = "10.20.0.0/16"
}

variable "primary_availability_zones" {
  description = "Availability Zones for primary Mumbai region."
  type        = list(string)

  default = [
    "ap-south-1a",
    "ap-south-1b",
    "ap-south-1c"
  ]
}

variable "dr_availability_zones" {
  description = "Availability Zones for DR Hyderabad region."
  type        = list(string)

  default = [
    "ap-south-2a",
    "ap-south-2b",
    "ap-south-2c"
  ]
}

# ============================================================
# EKS
# ============================================================

variable "primary_eks_name" {
  description = "Primary EKS cluster name."
  type        = string
  default     = "paysecure-primary"
}

variable "dr_eks_name" {
  description = "DR EKS cluster name."
  type        = string
  default     = "paysecure-dr"
}

variable "eks_node_instance_type" {
  description = "EKS worker node instance type."
  type        = string
  default     = "m6i.large"
}

variable "primary_eks_desired_nodes" {
  description = "Desired primary EKS node count."
  type        = number
  default     = 6
}

variable "dr_eks_desired_nodes" {
  description = "Desired DR EKS node count."
  type        = number
  default     = 3
}

# ============================================================
# AURORA POSTGRESQL
# ============================================================

variable "aurora_engine" {
  description = "Aurora database engine."
  type        = string
  default     = "aurora-postgresql"
}

variable "aurora_database_name" {
  description = "Aurora database name."
  type        = string
  default     = "paysecure"
}

variable "aurora_instance_class" {
  description = "Aurora DB instance class."
  type        = string
  default     = "db.r6g.large"
}

variable "aurora_master_username" {
  description = "Aurora master username. Supply securely using TF_VAR_aurora_master_username."
  type        = string
  sensitive   = true
}

variable "aurora_master_password" {
  description = "Aurora master password. Supply securely using TF_VAR_aurora_master_password."
  type        = string
  sensitive   = true
}

# ============================================================
# DYNAMODB
# ============================================================

variable "dynamodb_table_name" {
  description = "DynamoDB transaction table name."
  type        = string
  default     = "paysecure-transactions"
}

# ============================================================
# REDIS
# ============================================================

variable "redis_node_type" {
  description = "ElastiCache Redis node type."
  type        = string
  default     = "cache.r6g.large"
}

# ============================================================
# MSK / KAFKA
# ============================================================

variable "msk_kafka_version" {
  description = "Apache Kafka version used by MSK."
  type        = string
  default     = "3.8.x"
}

variable "msk_kms_key_arn" {
  description = "KMS key ARN used for MSK encryption."
  type        = string
  default     = null
}

# ============================================================
# ROUTE 53
# ============================================================

variable "enable_route53" {
  description = "Enable Route 53 DNS failover resources."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID."
  type        = string
  default     = ""
}

variable "route53_zone_name" {
  description = "Route 53 hosted zone name."
  type        = string
  default     = "paysecure.in"
}

variable "route53_record_name" {
  description = "Route 53 application record."
  type        = string
  default     = "api.paysecure.in"
}

variable "route53_primary_endpoint" {
  description = "Primary ALB endpoint."
  type        = string
  default     = ""
}

variable "route53_dr_endpoint" {
  description = "DR ALB endpoint."
  type        = string
  default     = ""
}

variable "route53_primary_alias_zone_id" {
  description = "Primary ALB Route 53 alias zone ID."
  type        = string
  default     = ""
}

variable "route53_dr_alias_zone_id" {
  description = "DR ALB Route 53 alias zone ID."
  type        = string
  default     = ""
}

# ============================================================
# OPTIONAL MODULE SWITCHES
# ============================================================

variable "enable_database" {
  description = "Enable Aurora database modules."
  type        = bool
  default     = false
}

variable "enable_eks" {
  description = "Enable EKS modules."
  type        = bool
  default     = false
}

variable "enable_msk" {
  description = "Enable MSK modules."
  type        = bool
  default     = false
}

variable "enable_redis" {
  description = "Enable Redis modules."
  type        = bool
  default     = false
}

variable "enable_dynamodb" {
  description = "Enable DynamoDB module."
  type        = bool
  default     = false
}


variable "project_name" {
description = "Project name used for resource naming and tagging."
type        = string
default     = "paysecure-dr"
}

variable "primary_region" {
description = "Primary AWS region for PaySecure production workloads."
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

variable "vpc_cidr_primary" {
description = "CIDR block for the primary Mumbai VPC."
type        = string
default     = "10.10.0.0/16"
}

variable "vpc_cidr_dr" {
description = "CIDR block for the DR Hyderabad VPC."
type        = string
default     = "10.20.0.0/16"
}

variable "availability_zones_primary" {
description = "Availability Zones used by the primary region."
type        = list(string)
default     = [
"ap-south-1a",
"ap-south-1b",
"ap-south-1c"
]
}

variable "availability_zones_dr" {
description = "Availability Zones used by the DR region."
type        = list(string)
default     = [
"ap-south-2a",
"ap-south-2b",
"ap-south-2c"
]
}

variable "eks_cluster_name_primary" {
description = "Primary EKS cluster name."
type        = string
default     = "paysecure-primary"
}

variable "eks_cluster_name_dr" {
description = "DR EKS cluster name."
type        = string
default     = "paysecure-dr"
}

variable "eks_node_instance_type" {
description = "EKS worker node instance type."
type        = string
default     = "m6i.large"
}

variable "eks_desired_nodes_primary" {
description = "Desired worker nodes in the primary cluster."
type        = number
default     = 6
}

variable "eks_desired_nodes_dr" {
description = "Desired worker nodes in the DR cluster."
type        = number
default     = 3
}

variable "aurora_engine" {
description = "Aurora PostgreSQL engine."
type        = string
default     = "aurora-postgresql"
}

variable "aurora_database_name" {
description = "PaySecure application database name."
type        = string
default     = "paysecure"
}

variable "aurora_instance_class" {
description = "Aurora DB instance class."
type        = string
default     = "db.r6g.large"
}

variable "dynamodb_table_name" {
description = "Primary DynamoDB table name."
type        = string
default     = "paysecure-transactions"
}

variable "redis_node_type" {
description = "ElastiCache Redis node type."
type        = string
default     = "cache.r6g.large"
}

variable "msk_kafka_version" {
description = "Amazon MSK Kafka version."
type        = string
default     = "3.8.x"
}

variable "route53_zone_id" {
description = "Existing Route 53 hosted zone ID."
type        = string
default     = ""
}

variable "enable_route53" {
description = "Enable Route 53 resources when an existing hosted zone is available."
type        = bool
default     = false
}

variable "enable_database" {
description = "Enable database infrastructure modules."
type        = bool
default     = false
}

variable "enable_eks" {
description = "Enable EKS infrastructure modules."
type        = bool
default     = false
}

variable "enable_msk" {
description = "Enable MSK infrastructure modules."
type        = bool
default     = false
}

variable "enable_redis" {
description = "Enable Redis infrastructure modules."
type        = bool
default     = false
}

variable "enable_dynamodb" {
description = "Enable DynamoDB infrastructure modules."
type        = bool
default     = false
}

variable "project_name" {
description = "Project name used for resource naming."
type        = string
}

variable "region" {
description = "AWS region for the networking resources."
type        = string
}

variable "environment" {
description = "Environment name, such as primary or dr."
type        = string
}

variable "vpc_cidr" {
description = "CIDR block for the VPC."
type        = string
}

variable "availability_zones" {
description = "Availability Zones used by the VPC."
type        = list(string)

validation {
condition     = length(var.availability_zones) >= 2
error_message = "At least two Availability Zones are required for the DR architecture."
}
}

variable "common_tags" {
description = "Common tags applied to networking resources."
type        = map(string)
default     = {}
}

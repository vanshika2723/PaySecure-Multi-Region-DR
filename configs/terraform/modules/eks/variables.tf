variable "cluster_name" {
description = "Name of the EKS cluster."
type        = string
}

variable "region" {
description = "AWS region where the EKS cluster is deployed."
type        = string
}

variable "environment" {
description = "Deployment environment."
type        = string
}

variable "subnet_ids" {
description = "Private subnet IDs used by the EKS cluster and node group."
type        = list(string)

validation {
condition     = length(var.subnet_ids) >= 2
error_message = "At least two subnets are required for the EKS cluster."
}
}

variable "kubernetes_version" {
description = "Kubernetes version for the EKS control plane."
type        = string
default     = "1.33"
}

variable "node_instance_type" {
description = "EC2 instance type for EKS worker nodes."
type        = string
default     = "m6i.large"
}

variable "desired_nodes" {
description = "Desired number of worker nodes."
type        = number
default     = 3

validation {
condition     = var.desired_nodes >= 1
error_message = "desired_nodes must be at least 1."
}
}

variable "min_nodes" {
description = "Minimum number of worker nodes."
type        = number
default     = 3
}

variable "max_nodes" {
description = "Maximum number of worker nodes."
type        = number
default     = 12
}

variable "capacity_type" {
description = "EKS node capacity type."
type        = string
default     = "ON_DEMAND"

validation {
condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
error_message = "capacity_type must be ON_DEMAND or SPOT."
}
}

variable "common_tags" {
description = "Common tags applied to EKS resources."
type        = map(string)
default     = {}
}

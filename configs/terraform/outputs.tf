output "project_name" {
description = "PaySecure DR project name."
value       = var.project_name
}

output "primary_region" {
description = "Primary AWS region."
value       = var.primary_region
}

output "dr_region" {
description = "Disaster recovery AWS region."
value       = var.dr_region
}

output "primary_eks_cluster_name" {
description = "Primary EKS cluster name."
value       = var.eks_cluster_name_primary
}

output "dr_eks_cluster_name" {
description = "DR EKS cluster name."
value       = var.eks_cluster_name_dr
}

output "primary_vpc_cidr" {
description = "Primary VPC CIDR."
value       = var.vpc_cidr_primary
}

output "dr_vpc_cidr" {
description = "DR VPC CIDR."
value       = var.vpc_cidr_dr
}

output "dr_strategy" {
description = "Selected disaster recovery strategy."
value       = "Hot Standby / Active-Passive"
}

output "target_rpo" {
description = "Target Recovery Point Objective."
value       = "< 1 minute"
}

output "target_rto" {
description = "Target Recovery Time Objective."
value       = "< 5 minutes"
}

output "target_availability" {
description = "Target platform availability."
value       = "99.99%"
}

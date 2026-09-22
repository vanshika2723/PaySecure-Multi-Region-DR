output "cluster_id" {
description = "EKS cluster ID."
value       = aws_eks_cluster.this.id
}

output "cluster_name" {
description = "EKS cluster name."
value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
description = "EKS cluster ARN."
value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
description = "EKS Kubernetes API endpoint."
value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
description = "EKS Kubernetes version."
value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
description = "EKS cluster security group ID."
value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
description = "EKS managed node group name."
value       = aws_eks_node_group.this.node_group_name
}

output "node_group_arn" {
description = "EKS managed node group ARN."
value       = aws_eks_node_group.this.arn
}

output "node_role_arn" {
description = "IAM role ARN used by EKS worker nodes."
value       = aws_iam_role.eks_nodes.arn
}

output "cluster_role_arn" {
description = "IAM role ARN used by the EKS control plane."
value       = aws_iam_role.eks_cluster.arn
}

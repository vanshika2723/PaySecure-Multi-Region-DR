data "aws_iam_policy_document" "eks_assume_role" {
statement {
effect = "Allow"

```
principals {
  type        = "Service"
  identifiers = ["eks.amazonaws.com"]
}

actions = [
  "sts:AssumeRole"
]
```

}
}

data "aws_iam_policy_document" "eks_node_assume_role" {
statement {
effect = "Allow"

```
principals {
  type        = "Service"
  identifiers = ["ec2.amazonaws.com"]
}

actions = [
  "sts:AssumeRole"
]
```

}
}

resource "aws_iam_role" "eks_cluster" {
name               = "${var.cluster_name}-cluster-role"
assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json

tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
role       = aws_iam_role.eks_cluster.name
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_nodes" {
name               = "${var.cluster_name}-node-role"
assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
role       = aws_iam_role.eks_nodes.name
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
role       = aws_iam_role.eks_nodes.name
policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
role       = aws_iam_role.eks_nodes.name
policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_cluster" "this" {
name     = var.cluster_name
role_arn = aws_iam_role.eks_cluster.arn
version  = var.kubernetes_version

vpc_config {
subnet_ids              = var.subnet_ids
endpoint_private_access = true
endpoint_public_access  = true
}

enabled_cluster_log_types = [
"api",
"audit",
"authenticator",
"controllerManager",
"scheduler"
]

tags = merge(
var.common_tags,
{
Name = var.cluster_name
}
)

depends_on = [
aws_iam_role_policy_attachment.eks_cluster_policy
]
}

resource "aws_eks_node_group" "this" {
cluster_name    = aws_eks_cluster.this.name
node_group_name = "${var.cluster_name}-workers"
node_role_arn   = aws_iam_role.eks_nodes.arn
subnet_ids      = var.subnet_ids

instance_types = [
var.node_instance_type
]

capacity_type = var.capacity_type

scaling_config {
desired_size = var.desired_nodes
min_size     = var.min_nodes
max_size     = var.max_nodes
}

update_config {
max_unavailable = 1
}

labels = {
Environment = var.environment
Workload     = "payment-platform"
}

tags = merge(
var.common_tags,
{
Name = "${var.cluster_name}-workers"
}
)

depends_on = [
aws_iam_role_policy_attachment.eks_worker_node_policy,
aws_iam_role_policy_attachment.eks_cni_policy,
aws_iam_role_policy_attachment.eks_ecr_policy
]
}

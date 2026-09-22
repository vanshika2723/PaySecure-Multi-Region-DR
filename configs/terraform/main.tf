locals {
common_tags = {
Project     = var.project_name
Environment = var.environment
ManagedBy   = "Terraform"
DRStrategy  = "Hot-Standby"
Compliance  = "PCI-DSS"
}
}

# -------------------------------------------------------------------

# Primary Region - Mumbai

# -------------------------------------------------------------------

module "primary_networking" {
source = "./modules/networking"

providers = {
aws = aws.primary
}

project_name        = var.project_name
region              = var.primary_region
vpc_cidr            = var.vpc_cidr_primary
availability_zones  = var.availability_zones_primary
environment         = "primary"
common_tags         = local.common_tags
}

# -------------------------------------------------------------------

# DR Region - Hyderabad

# -------------------------------------------------------------------

module "dr_networking" {
source = "./modules/networking"

providers = {
aws = aws.dr
}

project_name        = var.project_name
region              = var.dr_region
vpc_cidr            = var.vpc_cidr_dr
availability_zones  = var.availability_zones_dr
environment         = "dr"
common_tags         = local.common_tags
}

# -------------------------------------------------------------------

# EKS - Primary

# -------------------------------------------------------------------

module "primary_eks" {
count  = var.enable_eks ? 1 : 0
source = "./modules/eks"

providers = {
aws = aws.primary
}

cluster_name       = var.eks_cluster_name_primary
region             = var.primary_region
environment        = "primary"
node_instance_type = var.eks_node_instance_type
desired_nodes      = var.eks_desired_nodes_primary

vpc_id     = module.primary_networking.vpc_id
subnet_ids = module.primary_networking.private_subnet_ids

common_tags = local.common_tags
}

# -------------------------------------------------------------------

# EKS - DR

# -------------------------------------------------------------------

module "dr_eks" {
count  = var.enable_eks ? 1 : 0
source = "./modules/eks"

providers = {
aws = aws.dr
}

cluster_name       = var.eks_cluster_name_dr
region             = var.dr_region
environment        = "dr"
node_instance_type = var.eks_node_instance_type
desired_nodes      = var.eks_desired_nodes_dr

vpc_id     = module.dr_networking.vpc_id
subnet_ids = module.dr_networking.private_subnet_ids

common_tags = local.common_tags
}

# -------------------------------------------------------------------

# Aurora PostgreSQL

# -------------------------------------------------------------------

module "aurora" {
count  = var.enable_database ? 1 : 0
source = "./modules/aurora"

providers = {
aws.primary = aws.primary
aws.dr      = aws.dr
}

project_name        = var.project_name
database_name       = var.aurora_database_name
engine              = var.aurora_engine
instance_class      = var.aurora_instance_class

primary_region      = var.primary_region
dr_region           = var.dr_region

primary_vpc_id      = module.primary_networking.vpc_id
dr_vpc_id           = module.dr_networking.vpc_id

primary_subnet_ids  = module.primary_networking.database_subnet_ids
dr_subnet_ids       = module.dr_networking.database_subnet_ids

common_tags = local.common_tags
}

# -------------------------------------------------------------------

# DynamoDB

# -------------------------------------------------------------------

module "dynamodb" {
count  = var.enable_dynamodb ? 1 : 0
source = "./modules/dynamodb"

providers = {
aws.primary = aws.primary
aws.dr      = aws.dr
}

table_name      = var.dynamodb_table_name
primary_region  = var.primary_region
dr_region       = var.dr_region

common_tags = local.common_tags
}

# -------------------------------------------------------------------

# Redis

# -------------------------------------------------------------------

module "redis" {
count  = var.enable_redis ? 1 : 0
source = "./modules/redis"

providers = {
aws.primary = aws.primary
aws.dr      = aws.dr
}

project_name = var.project_name
node_type    = var.redis_node_type

primary_region = var.primary_region
dr_region      = var.dr_region

primary_vpc_id = module.primary_networking.vpc_id
dr_vpc_id      = module.dr_networking.vpc_id

common_tags = local.common_tags
}

# -------------------------------------------------------------------

# Amazon MSK

# -------------------------------------------------------------------

module "msk" {
count  = var.enable_msk ? 1 : 0
source = "./modules/msk"

providers = {
aws.primary = aws.primary
aws.dr      = aws.dr
}

project_name = var.project_name
kafka_version = var.msk_kafka_version

primary_region = var.primary_region
dr_region      = var.dr_region

primary_vpc_id = module.primary_networking.vpc_id
dr_vpc_id      = module.dr_networking.vpc_id

primary_subnet_ids = module.primary_networking.private_subnet_ids
dr_subnet_ids      = module.dr_networking.private_subnet_ids

common_tags = local.common_tags
}

# -------------------------------------------------------------------

# Route 53

# -------------------------------------------------------------------

module "route53" {
count  = var.enable_route53 ? 1 : 0
source = "./modules/route53"

providers = {
aws = aws.primary
}

project_name   = var.project_name
hosted_zone_id = var.route53_zone_id

common_tags = local.common_tags
}

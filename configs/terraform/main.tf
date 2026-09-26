
locals {
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    DRProject   = "PaySecure-Multi-Region"
    Environment = var.environment
  }
}

# ============================================================
# PRIMARY NETWORKING - MUMBAI
# ============================================================

module "primary_networking" {
  source = "./modules/networking"

  providers = {
    aws = aws.primary
  }

  project_name      = var.project_name
  region            = var.primary_region
  environment       = "primary"
  vpc_cidr          = var.vpc_cidr_primary
  availability_zones = var.primary_availability_zones
  common_tags       = local.common_tags
}

# ============================================================
# DR NETWORKING - HYDERABAD
# ============================================================

module "dr_networking" {
  source = "./modules/networking"

  providers = {
    aws = aws.dr
  }

  project_name      = var.project_name
  region            = var.dr_region
  environment       = "dr"
  vpc_cidr          = var.vpc_cidr_dr
  availability_zones = var.dr_availability_zones
  common_tags       = local.common_tags
}

# ============================================================
# PRIMARY EKS
# ============================================================

module "primary_eks" {
  count  = var.enable_eks ? 1 : 0
  source = "./modules/eks"

  providers = {
    aws = aws.primary
  }

  cluster_name        = var.primary_eks_name
  region              = var.primary_region
  environment         = "primary"
  subnet_ids          = module.primary_networking.private_subnet_ids
  node_instance_type  = var.eks_node_instance_type
  desired_nodes       = var.primary_eks_desired_nodes
  min_nodes           = 3
  max_nodes           = 12
  common_tags         = local.common_tags
}

# ============================================================
# DR EKS
# ============================================================

module "dr_eks" {
  count  = var.enable_eks ? 1 : 0
  source = "./modules/eks"

  providers = {
    aws = aws.dr
  }

  cluster_name        = var.dr_eks_name
  region              = var.dr_region
  environment         = "dr"
  subnet_ids          = module.dr_networking.private_subnet_ids
  node_instance_type  = var.eks_node_instance_type
  desired_nodes       = var.dr_eks_desired_nodes
  min_nodes           = 3
  max_nodes           = 12
  common_tags         = local.common_tags
}

# ============================================================
# PRIMARY AURORA
# ============================================================

module "primary_aurora" {
  count  = var.enable_database ? 1 : 0
  source = "./modules/aurora"

  providers = {
    aws = aws.primary
  }

  cluster_identifier = "${var.project_name}-primary"
  engine             = var.aurora_engine
  database_name      = var.aurora_database_name
  instance_class     = var.aurora_instance_class

  master_username = var.aurora_master_username
  master_password = var.aurora_master_password

  subnet_ids = module.primary_networking.database_subnet_ids

  # Security groups will be added during security-layer integration.
  vpc_security_group_ids = [
  aws_security_group.primary_database.id
]

  common_tags = local.common_tags
}

# ============================================================
# DR AURORA
# ============================================================

module "dr_aurora" {
  count  = var.enable_database ? 1 : 0
  source = "./modules/aurora"

  providers = {
    aws = aws.dr
  }

  cluster_identifier = "${var.project_name}-dr"
  engine             = var.aurora_engine
  database_name      = var.aurora_database_name
  instance_class     = var.aurora_instance_class

  master_username = var.aurora_master_username
  master_password = var.aurora_master_password

  subnet_ids = module.dr_networking.database_subnet_ids

 vpc_security_group_ids = [
  aws_security_group.dr_database.id
]

  common_tags = local.common_tags
}

# ============================================================
# DYNAMODB GLOBAL TABLE
# ============================================================

module "dynamodb" {
  count  = var.enable_dynamodb ? 1 : 0
  source = "./modules/dynamodb"

  providers = {
    aws = aws.primary
  }

  table_name      = var.dynamodb_table_name
  replica_regions = [var.dr_region]

  common_tags = local.common_tags
}

# ============================================================
# PRIMARY REDIS
# ============================================================

module "primary_redis" {
  count  = var.enable_redis ? 1 : 0
  source = "./modules/redis"

  providers = {
    aws = aws.primary
  }

  replication_group_id = "${var.project_name}-redis-primary"

  subnet_ids = module.primary_networking.private_subnet_ids

 security_group_ids = [
  aws_security_group.primary_application.id
]

  common_tags = local.common_tags
}

# ============================================================
# DR REDIS
# ============================================================

module "dr_redis" {
  count  = var.enable_redis ? 1 : 0
  source = "./modules/redis"

  providers = {
    aws = aws.dr
  }

  replication_group_id = "${var.project_name}-redis-dr"

  subnet_ids = module.dr_networking.private_subnet_ids

  security_group_ids = [
  aws_security_group.dr_application.id
]

  common_tags = local.common_tags
}

# ============================================================
# PRIMARY MSK
# ============================================================

module "primary_msk" {
  count  = var.enable_msk ? 1 : 0
  source = "./modules/msk"

  providers = {
    aws = aws.primary
  }

  cluster_name           = "${var.project_name}-msk-primary"
  kafka_version          = var.msk_kafka_version
  number_of_broker_nodes = 3

  subnet_ids = module.primary_networking.private_subnet_ids

  security_group_ids = [
  aws_security_group.primary_kafka.id
]

kms_key_arn = aws_kms_key.primary.arn

  common_tags = local.common_tags
}

# ============================================================
# DR MSK
# ============================================================

module "dr_msk" {
  count  = var.enable_msk ? 1 : 0
  source = "./modules/msk"

  providers = {
    aws = aws.dr
  }

  cluster_name           = "${var.project_name}-msk-dr"
  kafka_version          = var.msk_kafka_version
  number_of_broker_nodes = 3

  subnet_ids = module.dr_networking.private_subnet_ids

  security_group_ids = [
  aws_security_group.dr_kafka.id
]

kms_key_arn = aws_kms_replica_key.dr.arn

  common_tags = local.common_tags
}

# ============================================================
# ROUTE 53
# ============================================================

module "route53" {
  count  = var.enable_route53 ? 1 : 0
  source = "./modules/route53"

  providers = {
    aws = aws.primary
  }

  hosted_zone_id = var.route53_zone_id
  zone_name      = var.route53_zone_name
  record_name    = var.route53_record_name

  primary_region = var.primary_region
  dr_region      = var.dr_region

  primary_endpoint = var.route53_primary_endpoint
  dr_endpoint      = var.route53_dr_endpoint

  primary_alias_zone_id = var.route53_primary_alias_zone_id
  dr_alias_zone_id      = var.route53_dr_alias_zone_id

  common_tags = local.common_tags
}
```

### ⚠️ Abhi `terraform apply` mat karna

Is file mein kuch variables abhi `variables.tf` mein nahi hain:

```text
aurora_master_username
aurora_master_password
msk_kms_key_arn
route53_zone_name
route53_primary_endpoint
route53_dr_endpoint
route53_primary_alias_zone_id
route53_dr_alias_zone_id


provider "aws" {
alias  = "primary"
region = var.primary_region

default_tags {
tags = {
Project     = var.project_name
Environment = "primary"
ManagedBy   = "Terraform"
DRProject   = "PaySecure-Multi-Region"
}
}
}

provider "aws" {
alias  = "dr"
region = var.dr_region

default_tags {
tags = {
Project     = var.project_name
Environment = "dr"
ManagedBy   = "Terraform"
DRProject   = "PaySecure-Multi-Region"
}
}
}

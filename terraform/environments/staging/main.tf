terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  # Partial backend configuration — init with:
  #   terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  # All resources in this environment inherit these tags automatically.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  # DATABASE_URL secret ARN: sourced from the RDS module when enabled,
  # empty string otherwise (container receives DATABASE_URL via docker compose locally).
  database_url_secret_arn = var.create_rds ? module.rds["rds"].database_url_secret_arn : ""
}

# ── Dependency graph ──────────────────────────────────────────────────────────
#
#   networking
#     ├──▶ alb        (VPC + public subnets + ALB SG)
#     ├──▶ rds        (VPC + data subnets + RDS SG)       [optional]
#     └──▶ ecs        (VPC + private subnets + app SG
#                      + target_group_arn from alb
#                      + database_url_secret_arn from rds)
#
# Provisioning order: networking → alb + rds (parallel) → ecs

module "networking" {
  source = "../../modules/networking"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  data_subnet_cidrs    = var.data_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  security_group_id = module.networking.alb_security_group_id
  certificate_arn   = var.acm_certificate_arn
}

# RDS is disabled by default (create_rds = false). Enable in staging/prod via tfvars.
# for_each with a string key rather than count: immune to index-shift if the toggle
# is ever removed and re-added. Access outputs as module.rds["rds"].output_name.
module "rds" {
  for_each = var.create_rds ? { rds = true } : {}
  source   = "../../modules/rds"

  project             = var.project
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  data_subnet_ids     = module.networking.data_subnet_ids
  security_group_id   = module.networking.rds_security_group_id
  instance_class      = var.rds_instance_class
  multi_az            = var.rds_multi_az
  deletion_protection = var.rds_deletion_protection
}

module "ecs" {
  source = "../../modules/ecs"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  vpc_id      = module.networking.vpc_id

  private_subnet_ids      = module.networking.private_subnet_ids
  security_group_id       = module.networking.app_security_group_id
  target_group_arn        = module.alb.target_group_arn
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  container_image         = var.container_image
  cpu                     = var.ecs_cpu
  memory                  = var.ecs_memory
  desired_count           = var.ecs_desired_count
  min_capacity            = var.ecs_min_capacity
  max_capacity            = var.ecs_max_capacity
  database_url_secret_arn = local.database_url_secret_arn

  environment_variables = {
    APP_ENV      = var.environment
    CORS_ORIGINS = jsonencode(var.cors_origins)
  }
}

# ── Post-apply assertions (Terraform 1.5+) ────────────────────────────────────

check "alb_dns_assigned" {
  assert {
    condition     = module.alb.alb_dns_name != ""
    error_message = "ALB DNS name is empty — load balancer may not have been created successfully."
  }
}

check "ecr_repository_exists" {
  assert {
    condition     = module.ecs.ecr_repository_url != ""
    error_message = "ECR repository URL is empty — image pushes from CI will fail."
  }
}

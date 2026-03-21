# environments/dev/main.tf
# ─────────────────────────────────────────────────────────────
# Dev environment root module.


terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}


# ═════════════════════════════════════════════════════════════
# MODULE 1: NETWORKING
# ═════════════════════════════════════════════════════════════


module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true
}


# ═════════════════════════════════════════════════════════════
# MODULE 2: SECURITY
# ═════════════════════════════════════════════════════════════

module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment

  vpc_id = module.networking.vpc_id

  app_port = 8080
  db_port  = 5432
}


# ═════════════════════════════════════════════════════════════
# MODULE 3: COMPUTE
# ═════════════════════════════════════════════════════════════

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment

  # From networking module
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids

  # From security module
  alb_security_group_id = module.security.alb_security_group_id
  app_security_group_id = module.security.app_security_group_id

  # Compute sizing (dev = small and cheap)
  app_port             = 8080
  instance_type        = var.instance_type
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
  cpu_target_value     = 60.0

  # Health check settings
  health_check_path = "/health"
}


# ═════════════════════════════════════════════════════════════
# MODULE 4: DATABASE
# ═════════════════════════════════════════════════════════════

module "database" {
  source = "../../modules/database"

  project_name = var.project_name
  environment  = var.environment

  # From networking module
  db_subnet_group_name = module.networking.db_subnet_group_name

  # From security module
  db_security_group_id = module.security.db_security_group_id

  # Database configuration (dev = small, single-AZ, minimal backups)
  engine_version    = "15"
  instance_class    = var.db_instance_class
  allocated_storage = 20

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # Dev settings: no HA, minimal backups, easy cleanup
  multi_az                = false
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
}

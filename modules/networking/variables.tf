# modules/networking/variables.tf
# ─────────────────────────────────────────────────────────────
# Inputs for the networking module.

variable "project_name" {
  description = "Project name, used as prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "availability_zones" {
  description = "List of 2 availability zones (e.g., [\"us-east-1a\", \"us-east-1b\"])"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones must be provided."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ (e.g., [\"10.0.1.0/24\", \"10.0.2.0/24\"])"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly 2 public subnet CIDRs must be provided."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private/application subnets, one per AZ"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly 2 private subnet CIDRs must be provided."
  }
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets, one per AZ"
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_cidrs) == 2
    error_message = "Exactly 2 database subnet CIDRs must be provided."
  }
}

# ─────────────────────────────────────────────────────────────
# Cost Optimization
# ─────────────────────────────────────────────────────────────

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway. Costs ~\$32/month. Disable to save money when app servers don't need outbound internet."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "If true, create ONE NAT Gateway shared by all private subnets (cheaper but single point of failure). If false, one NAT per AZ (resilient but costs double). Use true for dev, false for prod."
  type        = bool
  default     = true
}

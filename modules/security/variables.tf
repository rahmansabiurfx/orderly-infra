# modules/security/variables.tf
# ─────────────────────────────────────────────────────────────
# Inputs for the security module.

variable "project_name" {
  description = "Project name, used as prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created. Comes from the networking module output."
  type        = string
}

variable "app_port" {
  description = "Port the application listens on inside the container/instance"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port the database listens on (5432 for PostgreSQL)"
  type        = number
  default     = 5432
}

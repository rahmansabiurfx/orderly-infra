# modules/database/variables.tf
# ─────────────────────────────────────────────────────────────
# Inputs for the database module.


# ─── Naming ────────────────────────────────────────────────

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# ─── Network Inputs (from networking module) ───────────────

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group where RDS will be placed"
  type        = string
}

# ─── Security Inputs (from security module) ────────────────

variable "db_security_group_id" {
  description = "Security group ID to attach to the RDS instance"
  type        = string
}

# ─── Database Engine Configuration ─────────────────────────

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15"
}

variable "instance_class" {
  description = "RDS instance class (e.g., db.t3.micro, db.t3.small)"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial storage allocation in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage in GB for autoscaling. Set to 0 to disable storage autoscaling."
  type        = number
  default     = 100
}

# ─── Database Credentials ──────────────────────────────────

variable "db_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for the database. NEVER commit this value to Git."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters."
  }
}

# ─── High Availability ────────────────────────────────────

variable "multi_az" {
  description = "Enable Multi-AZ deployment (standby replica in another AZ). Use true for prod, false for dev."
  type        = bool
  default     = false
}

# ─── Backup Configuration ─────────────────────────────────

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (0 to disable)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Daily time range for automated backups (UTC). Format: HH:MM-HH:MM. Must not overlap with maintenance window."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly time range for maintenance (UTC). Format: ddd:HH:MM-ddd:HH:MM."
  type        = string
  default     = "sun:04:30-sun:05:30"
}

# ─── Protection ────────────────────────────────────────────

variable "deletion_protection" {
  description = "Prevent accidental deletion of the database. Use true for prod, false for dev."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting. Use false for prod (takes snapshot), true for dev (faster cleanup)."
  type        = bool
  default     = true
}

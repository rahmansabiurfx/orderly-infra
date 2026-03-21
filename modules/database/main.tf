# modules/database/main.tf
# ─────────────────────────────────────────────────────────────
# RDS PostgreSQL database for the data tier.


locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "database"
  }

  name_prefix = "${var.project_name}-${var.environment}"
}




# ═════════════════════════════════════════════════════════════
# RDS POSTGRESQL INSTANCE
# ═════════════════════════════════════════════════════════════

resource "aws_db_instance" "main" {
  # ─── Identifier ────────────────────────────────────────
  identifier = "${local.name_prefix}-postgres"

  # ─── Engine ────────────────────────────────────────────
  engine         = "postgres"
  engine_version = var.engine_version  # "15"

  # ─── Instance Size ─────────────────────────────────────
  instance_class = var.instance_class

  # ─── Storage ───────────────────────────────────────────
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # ─── Database Configuration ────────────────────────────
  db_name  = var.db_name      # Creates this database on launch
  username = var.db_username   # Master username
  password = var.db_password   # Master password (marked sensitive)
  port     = 5432              # PostgreSQL default port

  # ─── Network ───────────────────────────────────────────
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.db_security_group_id]

  publicly_accessible = false

  # ─── High Availability ─────────────────────────────────
  multi_az = var.multi_az

  # ─── Backup ────────────────────────────────────────────
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window

  # ─── Maintenance ───────────────────────────────────────
  maintenance_window = var.maintenance_window

  auto_minor_version_upgrade = true

  # ─── Protection ────────────────────────────────────────
  deletion_protection = var.deletion_protection

  # Final snapshot configuration:
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-final-snapshot"

  # ─── Parameter Group ───────────────────────────────────
  # Use the default parameter group for PostgreSQL 15.

  # ─── Logging ───────────────────────────────────────────
  # Export these PostgreSQL log types to CloudWatch Logs.
  # Useful for debugging slow queries and connection issues.
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # ─── Performance Insights ──────────────────────────────
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # ─── Tags ──────────────────────────────────────────────
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })
}

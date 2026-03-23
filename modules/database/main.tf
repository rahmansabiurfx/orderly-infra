# modules/database/main.tf
# ─────────────────────────────────────────────────────────────
# RDS PostgreSQL database with Secrets Manager integration.
#
# Creates:
#   - Random secure password
#   - AWS Secrets Manager secret
#   - RDS PostgreSQL instance
# ─────────────────────────────────────────────────────────────

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

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
# PASSWORD GENERATION
# ═════════════════════════════════════════════════════════════

resource "random_password" "db_password" {
  length = 32
  upper   = true
  lower   = true
  numeric = true
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


# ═════════════════════════════════════════════════════════════
# SECRETS MANAGER — SECRET CONTAINER
# ═════════════════════════════════════════════════════════════

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name_prefix}-db-credentials"
  description = "RDS PostgreSQL credentials for ${local.name_prefix}"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-credentials"
  })
}


# ═════════════════════════════════════════════════════════════
# SECRETS MANAGER — SECRET VALUE
# ═════════════════════════════════════════════════════════════

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    connection_string = "postgresql://${var.db_username}:${random_password.db_password.result}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
  })
}


# ═════════════════════════════════════════════════════════════
# RDS POSTGRESQL INSTANCE
# ═════════════════════════════════════════════════════════════

resource "aws_db_instance" "main" {
  # ─── Identifier ────────────────────────────────────────
  identifier = "${local.name_prefix}-postgres"

  # ─── Engine ────────────────────────────────────────────
  engine         = "postgres"
  engine_version = var.engine_version

  # ─── Instance Size ─────────────────────────────────────
  instance_class = var.instance_class

  # ─── Storage ───────────────────────────────────────────
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # ─── Database Configuration ────────────────────────────
  db_name  = var.db_name
  username = var.db_username
  port     = 5432

  password = random_password.db_password.result

  # ─── Network ───────────────────────────────────────────
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false

  # ─── High Availability ─────────────────────────────────
  multi_az = var.multi_az

  # ─── Backup ────────────────────────────────────────────
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window

  # ─── Maintenance ───────────────────────────────────────
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = true

  # ─── Protection ────────────────────────────────────────
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-final-snapshot"

  # ─── Logging ───────────────────────────────────────────
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # ─── Performance Insights ──────────────────────────────
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # ─── Tags ──────────────────────────────────────────────
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })
}

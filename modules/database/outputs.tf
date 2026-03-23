# modules/database/outputs.tf
# ─────────────────────────────────────────────────────────────
# Database connection information and Secrets Manager references.
# ─────────────────────────────────────────────────────────────

output "db_endpoint" {
  description = "Connection endpoint (hostname:port) for the database"
  value       = aws_db_instance.main.endpoint
}

output "db_hostname" {
  description = "Hostname of the database (without port)"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Port the database listens on"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Name of the default database"
  value       = aws_db_instance.main.db_name
}

output "db_instance_id" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.main.id
}

output "db_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

# ─── Secrets Manager Outputs ──────────────────────────────

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials. Applications use this ARN to retrieve connection details at runtime."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

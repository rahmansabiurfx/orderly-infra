# environments/dev/outputs.tf

# ─── Networking ────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB)"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (App servers)"
  value       = module.networking.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs (RDS)"
  value       = module.networking.database_subnet_ids
}

# ─── Application Access ───────────────────────────────────

output "alb_dns_name" {
  description = "ALB DNS name — visit this URL to access the application"
  value       = module.compute.alb_dns_name
}

output "application_url" {
  description = "Full URL to access the application"
  value       = "http://${module.compute.alb_dns_name}"
}

# ─── Database ─────────────────────────────────────────────

output "db_endpoint" {
  description = "Database connection endpoint (hostname:port)"
  value       = module.database.db_endpoint
}

output "db_hostname" {
  description = "Database hostname"
  value       = module.database.db_hostname
}

# ─── Secrets Manager ──────────────────────────────────────

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = module.database.db_secret_arn
}

output "db_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = module.database.db_secret_name
}

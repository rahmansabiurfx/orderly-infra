# environments/prod/outputs.tf

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs"
  value       = module.networking.database_subnet_ids
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.compute.alb_dns_name
}

output "application_url" {
  description = "Application URL"
  value       = "http://${module.compute.alb_dns_name}"
}

output "db_endpoint" {
  description = "Database endpoint"
  value       = module.database.db_endpoint
}

output "db_hostname" {
  description = "Database hostname"
  value       = module.database.db_hostname
}

# modules/security/outputs.tf
# ─────────────────────────────────────────────────────────────
# Security group IDs for other modules to use.



output "alb_security_group_id" {
  description = "ID of the ALB security group — attach to the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID of the application security group — attach to EC2 instances"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "ID of the database security group — attach to RDS instance"
  value       = aws_security_group.db.id
}

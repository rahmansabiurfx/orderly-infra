# modules/compute/variables.tf
# ─────────────────────────────────────────────────────────────
# CHANGE FROM PREVIOUS VERSION:
#   - Added: db_secret_arn for Secrets Manager IAM policy
# ─────────────────────────────────────────────────────────────

# ─── Naming ────────────────────────────────────────────────

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# ─── Region ────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

# ─── Network Inputs (from networking module) ───────────────

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instances"
  type        = list(string)
}

# ─── Security Inputs (from security module) ────────────────

variable "alb_security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "app_security_group_id" {
  description = "Security group ID for app EC2 instances"
  type        = string
}

# ─── Secrets Manager (from database module) ────────────────

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  type        = string
  default     = ""
}

# ─── Application Configuration ─────────────────────────────

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}

# ─── EC2 Instance Configuration ────────────────────────────

variable "instance_type" {
  description = "EC2 instance type (e.g., t3.micro, t3.small)"
  type        = string
  default     = "t3.micro"
}

# ─── Auto Scaling Configuration ────────────────────────────

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances the ASG can scale to"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Initial number of instances to launch"
  type        = number
  default     = 2
}

variable "cpu_target_value" {
  description = "Target average CPU utilization (%) for auto scaling"
  type        = number
  default     = 60.0
}

# ─── Health Check Configuration ────────────────────────────

variable "health_check_path" {
  description = "URL path the ALB uses for health checks"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Seconds between health checks"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Seconds to wait for a health check response"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Consecutive successful checks before marking healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Consecutive failed checks before marking unhealthy"
  type        = number
  default     = 3
}

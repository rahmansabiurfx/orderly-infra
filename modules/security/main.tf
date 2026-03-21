# modules/security/main.tf
# ─────────────────────────────────────────────────────────────
# Security groups for the three-tier architecture.


locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "security"
  }

  name_prefix = "${var.project_name}-${var.environment}"
}


# ═════════════════════════════════════════════════════════════
# ALB SECURITY GROUP
# ═════════════════════════════════════════════════════════════
# Attached to: Application Load Balancer
# Purpose: Control what traffic can reach the load balancer


resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Controls traffic to/from the Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
    Tier = "public"
  })
 
  lifecycle {
    create_before_destroy = true
  }
}


# ─── ALB Inbound Rules ────────────────────────────────────


resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet"
}


resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from internet"
}


# ─── ALB Outbound Rules ───────────────────────────────────


resource "aws_security_group_rule" "alb_egress_to_app" {
  type                     = "egress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow outbound to app servers on port ${var.app_port}"
}


# ═════════════════════════════════════════════════════════════
# APPLICATION SECURITY GROUP
# ═════════════════════════════════════════════════════════════
# Attached to: EC2 instances in the Auto Scaling Group
# Purpose: Control what traffic can reach the app servers


resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Controls traffic to/from application EC2 instances"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-sg"
    Tier = "private"
  })

  lifecycle {
    create_before_destroy = true
  }
}


# ─── App Inbound Rules ────────────────────────────────────


resource "aws_security_group_rule" "app_ingress_from_alb" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow inbound from ALB on port ${var.app_port}"
}


# ─── App Outbound Rules ───────────────────────────────────


resource "aws_security_group_rule" "app_egress_to_db" {
  type                     = "egress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id
  security_group_id        = aws_security_group.app.id
  description              = "Allow outbound to database on port ${var.db_port}"
}


resource "aws_security_group_rule" "app_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow outbound HTTPS (updates, AWS APIs)"
}


resource "aws_security_group_rule" "app_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow outbound HTTP (package repos)"
}


resource "aws_security_group_rule" "app_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow outbound DNS (TCP)"
}



resource "aws_security_group_rule" "app_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow outbound DNS (UDP)"
}


# ═════════════════════════════════════════════════════════════
# DATABASE SECURITY GROUP
# ═════════════════════════════════════════════════════════════
# Attached to: RDS PostgreSQL instance
# Purpose: Maximum restriction — only app servers can connect


resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Controls traffic to/from the RDS database - app servers only"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-sg"
    Tier = "database"
  })

  lifecycle {
    create_before_destroy = true
  }
}


# ─── Database Inbound Rules ───────────────────────────────


resource "aws_security_group_rule" "db_ingress_from_app" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.db.id
  description              = "Allow PostgreSQL from app servers only"
}


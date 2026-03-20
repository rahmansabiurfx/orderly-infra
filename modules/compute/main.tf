# modules/compute/main.tf
# ─────────────────────────────────────────────────────────────
# Compute resources for the application tier


locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "compute"
  }

  name_prefix = "${var.project_name}-${var.environment}"
}




# ═════════════════════════════════════════════════════════════
# AMI DATA SOURCE
# ═════════════════════════════════════════════════════════════

data "aws_ami" "amazon_linux" {
  # Return only the single most recent matching AMI
  most_recent = true

  # Only consider AMIs owned by Amazon (account ID 137112412989)
  # This prevents someone from publishing a malicious AMI with
  # a similar name that we accidentally pick up.
  owners = ["amazon"]

  # Filter by name pattern — Amazon Linux 2023 AMIs follow this naming
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  # Only HVM virtualization (modern, full hardware virtualization)
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Only EBS-backed AMIs (standard for modern instances)
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  # Only 64-bit architecture
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# ═════════════════════════════════════════════════════════════
# IAM ROLE + INSTANCE PROFILE
# ═════════════════════════════════════════════════════════════


resource "aws_iam_role" "app" {
  name = "${local.name_prefix}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-role"
  })
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "app_cloudwatch" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name_prefix}-app-profile"
  role = aws_iam_role.app.name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-profile"
  })
}


# ═════════════════════════════════════════════════════════════
# LAUNCH TEMPLATE
# ═════════════════════════════════════════════════════════════


resource "aws_launch_template" "app" {
  name        = "${local.name_prefix}-app-lt"
  description = "Launch template for ${local.name_prefix} application servers"

  image_id = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [var.app_security_group_id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_port     = var.app_port
    environment  = var.environment
    project_name = var.project_name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Forces IMDSv2
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-app-instance"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-app-volume"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-lt"
  })
}


# ═════════════════════════════════════════════════════════════
# APPLICATION LOAD BALANCER
# ═════════════════════════════════════════════════════════════


resource "aws_lb" "app" {
  name               = "${local.name_prefix}-alb"
  internal           = false  # false = internet-facing (has public IP)
  load_balancer_type = "application"  # Layer 7 (HTTP/HTTPS)
  security_groups    = [var.alb_security_group_id]

  subnets = var.public_subnet_ids
  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}


# ─── Target Group ──────────────────────────────────────────
# Defines the pool of instances and how to health-check them.

resource "aws_lb_target_group" "app" {
  name     = "${local.name_prefix}-app-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path       # GET /health
    port                = "traffic-port"               # Same port as app (8080)
    protocol            = "HTTP"
    interval            = var.health_check_interval    # Check every 30 seconds
    timeout             = var.health_check_timeout     # Wait 5 seconds for response
    healthy_threshold   = var.healthy_threshold         # 2 successes → healthy
    unhealthy_threshold = var.unhealthy_threshold       # 3 failures → unhealthy
    matcher             = "200"                         # Only HTTP 200 = healthy
  }

  deregistration_delay = 60

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-tg"
  })
}

# ─── Listener ──────────────────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-http-listener"
  })
}


# ═════════════════════════════════════════════════════════════
# AUTO SCALING GROUP
# ═════════════════════════════════════════════════════════════

resource "aws_autoscaling_group" "app" {
  name                = "${local.name_prefix}-app-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 180  # Wait 3 minutes after launch before checking

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"  # Always use the latest version
  }


  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50  # Keep at least 50% healthy during refresh
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-app-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ─── Auto Scaling Policy ──────────────────────────────────

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${local.name_prefix}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value  # 60.0
  }
}

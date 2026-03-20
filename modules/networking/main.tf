# modules/networking/main.tf
# ─────────────────────────────────────────────────────────────
# Network foundation for the three-tier architecture.
# ─────────────────────────────────────────────────────────────



# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────
# locals are computed values used within this module.

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "networking"
  }

  name_prefix = "${var.project_name}-${var.environment}"
}


# ═════════════════════════════════════════════════════════════
# VPC
# ═════════════════════════════════════════════════════════════

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}


# ═════════════════════════════════════════════════════════════
# SUBNETS
# ═════════════════════════════════════════════════════════════

# ─── Public Subnets ─────────────────────────────────────────

resource "aws_subnet" "public" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

# ─── Private Subnets ───────────────────────────────────────

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}

# ─── Database Subnets ──────────────────────────────────────

resource "aws_subnet" "database" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-${var.availability_zones[count.index]}"
    Tier = "database"
  })
}


# ═════════════════════════════════════════════════════════════
# INTERNET GATEWAY
# ═════════════════════════════════════════════════════════════

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}


# ═════════════════════════════════════════════════════════════
# ELASTIC IP(s) for NAT Gateway
# ═════════════════════════════════════════════════════════════

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 0
  domain = "vpc"


  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })
  depends_on = [aws_internet_gateway.main]
}


# ═════════════════════════════════════════════════════════════
# NAT GATEWAY(s)
# ═════════════════════════════════════════════════════════════


resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id = aws_subnet.public[count.index].id


  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-gw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}


# ═════════════════════════════════════════════════════════════
# ROUTE TABLES
# ═════════════════════════════════════════════════════════════

# ─── Public Route Table ────────────────────────────────────


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# ─── Private Route Table(s) ───────────────────────────────


resource "aws_route_table" "private" {
  # Always create at least 1, create 2 if we have dual NATs
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 1

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
    Tier = "private"
  })
}


# The NAT route — only created if NAT Gateway exists
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"

  # If single NAT: always use nat[0]. If dual NAT: use matching index.
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}


# Associate private subnets with their route tables
resource "aws_route_table_association" "private" {
  count = 2

  subnet_id = aws_subnet.private[count.index].id

  # If single NAT: both subnets use route table [0]
  # If dual NAT: each subnet uses its matching route table
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}



# ─── Database Route Table ─────────────────────────────────


resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-rt"
    Tier = "database"
  })
}

resource "aws_route_table_association" "database" {
  count = 2

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}


# ═════════════════════════════════════════════════════════════
# RDS SUBNET GROUP
# ═════════════════════════════════════════════════════════════


resource "aws_db_subnet_group" "database" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Database subnet group spanning 2 AZs for ${local.name_prefix}"

  subnet_ids = aws_subnet.database[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

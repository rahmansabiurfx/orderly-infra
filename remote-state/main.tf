# remote-state/main.tf
# ─────────────────────────────────────────────────────────────
# Terraform Remote State Backend — Bootstrap Configuration
#
# This creates TWO resources:
#   1. S3 Bucket     → Stores the state file (encrypted, versioned)
#   2. DynamoDB Table → Provides locking (prevents concurrent access)
#
# DEPLOYMENT: This is applied ONCE at the start of the project.
#             After that, it's rarely touched.
#
# STATE: This configuration uses LOCAL state (the bootstrap
#        exception). All other configurations use the S3 backend
#        that this configuration creates.
# ─────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────
# TERRAFORM SETTINGS BLOCK
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ─────────────────────────────────────────────────────────────
# PROVIDER CONFIGURATION
# ─────────────────────────────────────────────────────────────

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Component = "remote-state"
    }
  }
}

# ─────────────────────────────────────────────────────────────
# S3 BUCKET — State File Storage
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "terraform_state" {
  bucket        = var.state_bucket_name
  force_destroy = false

  tags = {
    Name        = var.state_bucket_name
    Description = "Stores Terraform state files for ${var.project_name}"
  }
}

# ─── Versioning ────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ─── Server-Side Encryption ────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ─── Block All Public Access ────────────────────────────────

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────────────────────
# DYNAMODB TABLE — State Locking
# ─────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = var.dynamodb_table_name
    Description = "Provides state locking for Terraform"
  }
}

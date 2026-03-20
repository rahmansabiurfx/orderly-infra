#remote-state/variables.tf
# ─────────────────────────────────────────────────────────────
#Input variables for the remote state backend.
#
#These define what information this configuration needs.
#The actual values are provided when terraform apply is run
#(via -var flags or a .tfvars file).
# ─────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region where state resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "multitier-infra"
}

variable "state_bucket_name" {
  description = "Globally unique name for the S3 bucket that stores terraform state"
  type        = string
  # No default - S3 names are gloabally unique
}

variable "dynamodb_table_name" {
  description = "Name for the DynamoDb table used for state locking"
  type        = string
  default     = "terraform-state-lock"
}

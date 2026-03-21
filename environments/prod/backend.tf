# environments/prod/backend.tf
# ─────────────────────────────────────────────────────────────
# Remote state backend configuration.

terraform {
  backend "s3" {
    bucket         = "rahmansabiurfx-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "rahmansabiurfx-state-locks"
    encrypt        = true
  }
}

# remote-state/outputs.tf
# ─────────────────────────────────────────────────────────────
# Values displayed after terraform apply.
#
# You'll need these values to configure the backend in
# environments/dev/backend.tf and environments/prod/backend.tf
# ─────────────────────────────────────────────────────────────

output "state_bucket_name" {
  description = "S3 bucket name — use this in backend.tf 'bucket' field"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN (Amazon Resource Name)"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name — use this in backend.tf 'dynamodb_table' field"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "aws_region" {
  description = "AWS region — use this in backend.tf 'region' field"
  value       = var.aws_region
}

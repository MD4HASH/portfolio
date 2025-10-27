# --- Outputs
output "config_bucket_name" {
  value = aws_s3_bucket.config_bucket.bucket
}

output "config_role_arn" {
  value = aws_iam_role.config_role.arn
}

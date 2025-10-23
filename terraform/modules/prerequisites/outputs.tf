# ----------------------------
# Outputs
# ----------------------------
output "tf_state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "pipeline_artifacts_bucket_name" {
  value = aws_s3_bucket.pipeline_artifacts.bucket
}

output "dynamodb_lock_table" {
  value = aws_dynamodb_table.tf_lock.name
}

output "codebuild_role_arn" {
  value       = aws_iam_role.codebuild_role.arn
  description = "ARN of the CodeBuild service role"
}

output "codepipeline_role_arn" {
  value       = aws_iam_role.codepipeline_role.arn
  description = "ARN of the CodePipeline service role"
}


output "init_main_command" {
  value       = <<EOT
BUCKET=$(cd ./prerequisites && terraform output -raw tf_state_bucket_name)
TABLE=$(cd ./prerequisites && terraform output -raw dynamodb_lock_table)
terraform init -reconfigure \\
  -backend-config="bucket=$(terraform output -raw tf_state_bucket_name -state=./prerequisites/terraform.tfstate)" \
  -backend-config="dynamodb_table=$(terraform output -raw dynamodb_lock_table -state=./prerequisites/terraform.tfstate)"
EOT
  description = "Command to initialize the main Terraform project with dynamic backend config from prerequisites outputs"
}

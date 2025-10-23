# ----------------------------
# Random suffixes for uniqueness
# ----------------------------

# Shared suffix for state-related resources
resource "random_id" "suffix" {
  byte_length = 4
}

# ----------------------------
# S3 Buckets
# ----------------------------

# Terraform state bucket
resource "aws_s3_bucket" "tf_state" {
  bucket        = "my-tf-state-bucket-${random_id.suffix.hex}"
  force_destroy = true
}

# Versioning
resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_encryption" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Pipeline artifact bucket
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "my-codepipeline-artifacts-${random_id.suffix.hex}"
  force_destroy = true
}

# ----------------------------
# DynamoDB Table for State Locking
# ----------------------------
resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-lock-${random_id.suffix.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# ----------------------------
# IAM Roles
# ----------------------------

# CodePipeline Role
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:*",
          "codebuild:*",
          "s3:*",
          "iam:PassRole",
          "sts:GetServiceBearerToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodeBuild Role
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "logs:*",
          "ec2:*",
          "dynamodb:*",
          "ssm:*"
        ]
        Resource = "*"
      }
    ]
  })
}



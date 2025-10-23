# modules/config/main.tf

# --- S3 bucket for AWS Config
resource "aws_s3_bucket" "config_bucket" {
  bucket        = "aws-config-${var.account_id}"
  force_destroy = true # optional, allows bucket deletion for testing
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Objects
      {
        Sid       = "AWSConfigObjectsPermissions"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.config_bucket.arn}/*"
      },
      # Bucket itself
      {
        Sid       = "AWSConfigBucketPermissions"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.config_bucket.arn
      }
    ]
  })
}



# --- IAM Role for AWS Config
resource "aws_iam_role" "config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

# Attach AWS managed policy
resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# --- Config Recorder
resource "aws_config_configuration_recorder" "main" {
  name     = "config-recorder"
  role_arn = aws_iam_role.config_role.arn
}

# --- Delivery Channel
resource "aws_config_delivery_channel" "main" {
  name           = "config-delivery"
  s3_bucket_name = aws_s3_bucket.config_bucket.bucket
}

# --- Enable Config Recorder
resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
}

# --- Outputs
output "config_bucket_name" {
  value = aws_s3_bucket.config_bucket.bucket
}

output "config_role_arn" {
  value = aws_iam_role.config_role.arn
}

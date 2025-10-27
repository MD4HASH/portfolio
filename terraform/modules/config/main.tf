# --- S3 bucket for AWS Config
resource "aws_s3_bucket" "config_bucket" {
  bucket        = "aws-config-${var.account_id}"
  force_destroy = true # allows bucket deletion for testing
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow AWS Config to put objects into the bucket
      {
        Sid       = "AWSConfigObjectsPermissions"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:PutObject"]
        Resource  = "${aws_s3_bucket.config_bucket.arn}/*"
      },
      # Allow AWS Config to read bucket ACL and location
      {
        Sid       = "AWSConfigBucketPermissions"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:GetBucketLocation"]
        Resource  = aws_s3_bucket.config_bucket.arn
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
        Action    = "sts:AssumeRole"
        Principal = { Service = "config.amazonaws.com" }
        Effect    = "Allow"
      }
    ]
  })
}

# --- Custom inline policy for AWS Config
resource "aws_iam_role_policy" "config_inline_policy" {
  name = "aws-config-inline-policy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "${aws_s3_bucket.config_bucket.arn}",
          "${aws_s3_bucket.config_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "config:Put*",
          "config:Delete*",
          "config:Start*",
          "config:Stop*",
          "config:Describe*",
          "config:Get*"
        ]
        Resource = "*"
      }
    ]
  })
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

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.main
  ]
}

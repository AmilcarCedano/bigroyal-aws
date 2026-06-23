data "aws_caller_identity" "current" {}

# Bucket S3 donde CloudTrail almacena los logs inmutables
resource "aws_s3_bucket" "trail" {
  bucket        = "${var.resource_prefix}-cloudtrail-logs"
  force_destroy = false
  tags          = var.common_tags
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    id     = "expire-cloudtrail-logs"
    status = "Enabled"
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

# Política del bucket para que CloudTrail pueda escribir
resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.trail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.trail.arn,
          "${aws_s3_bucket.trail.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# SNS Topic para notificaciones de CloudTrail
resource "aws_sns_topic" "trail_alerts" {
  name              = "${var.resource_prefix}-cloudtrail-alerts"
  kms_master_key_id = var.kms_key_arn
  tags              = var.common_tags
}

# Trail multi-región — registra acciones de los 3 colaboradores (RNF-18)
resource "aws_cloudtrail" "main" {
  name                          = "${var.resource_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_arn
  sns_topic_name                = aws_sns_topic.trail_alerts.arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw.arn

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.resource_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
  tags              = var.common_tags
}

resource "aws_iam_role" "cloudtrail_cw" {
  name = "${var.resource_prefix}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cw" {
  name = "${var.resource_prefix}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
    }]
  })
}

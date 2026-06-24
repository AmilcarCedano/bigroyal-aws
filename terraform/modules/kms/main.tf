data "aws_caller_identity" "current" {}

# Clave KMS para cifrar datos en reposo (Aurora + S3)
# Política explícita sin wildcards en Principal — CKV2_AWS_64
resource "aws_kms_key" "main" {
  description             = "Clave KMS para ${var.project_name} (${var.env}) — cifra Aurora y S3"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootAccount"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = { Service = "logs.amazonaws.com" }
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrail"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, { Name = "${var.resource_prefix}-kms" })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.resource_prefix}-main"
  target_key_id = aws_kms_key.main.key_id
}

data "aws_caller_identity" "current" {}

# Clave KMS para cifrar datos en reposo (Aurora + S3)
resource "aws_kms_key" "main" {
  description             = "Clave KMS para ${var.project_name} (${var.env}) — cifra Aurora y S3"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, { Name = "${var.resource_prefix}-kms" })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.resource_prefix}-main"
  target_key_id = aws_kms_key.main.key_id
}

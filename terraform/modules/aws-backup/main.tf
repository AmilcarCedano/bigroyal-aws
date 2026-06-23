data "aws_caller_identity" "current" {}

# IAM Role para AWS Backup
resource "aws_iam_role" "backup" {
  name = "${var.resource_prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Vault donde se almacenan los backups (cifrado con KMS)
resource "aws_backup_vault" "main" {
  name        = "${var.resource_prefix}-backup-vault"
  kms_key_arn = var.kms_key_arn
  tags        = var.common_tags
}

# Plan de backup continuo (WAL) + retención 7 días → RPO ≤ 5 min (RNF-14)
resource "aws_backup_plan" "aurora" {
  name = "${var.resource_prefix}-aurora-backup"

  rule {
    rule_name         = "continuo-7dias"
    target_vault_name = aws_backup_vault.main.name

    # Backup continuo (Point-in-Time Recovery) — RPO de 5 minutos
    enable_continuous_backup = true

    # Retención de 7 días
    lifecycle {
      delete_after = 7
    }
  }

  tags = var.common_tags
}

# Asociar el plan al cluster Aurora
resource "aws_backup_selection" "aurora" {
  name         = "${var.resource_prefix}-aurora-selection"
  plan_id      = aws_backup_plan.aurora.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [var.aurora_cluster_arn]
}

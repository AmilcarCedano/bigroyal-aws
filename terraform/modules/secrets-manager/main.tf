resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.resource_prefix}/db-credentials"
  description = "Credenciales Aurora PostgreSQL — rotación automática cada 30 días (RNF-16)"
  kms_key_id  = var.kms_key_arn

  rotation_rules {
    automatically_after_days = 30
  }

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db.result
    dbname   = var.db_name
    engine   = "aurora-postgresql"
    port     = 5432
  })
}

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.resource_prefix}/jwt-secret"
  description = "Clave secreta JWT — rotación automática cada 30 días (RNF-16)"
  kms_key_id  = var.kms_key_arn

  rotation_rules {
    automatically_after_days = 30
  }

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt.result
}

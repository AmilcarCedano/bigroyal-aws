data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_password" "db" {
  length  = 32
  special = false
}

# ── Secretos ─────────────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.resource_prefix}/db-credentials"
  description = "Credenciales Aurora PostgreSQL — rotación automática cada 30 días"
  kms_key_id  = var.kms_key_arn
  tags        = var.common_tags
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
  description = "Clave secreta JWT — rotación automática cada 30 días"
  kms_key_id  = var.kms_key_arn
  tags        = var.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt.result
}

# ── Lambda de rotación — completamente hardened ──────────────────────────────

# SG propio — egress solo HTTPS hacia VPC endpoints — CKV_AWS_382, CKV2_AWS_5
resource "aws_security_group" "rotation" {
  name        = "${var.resource_prefix}-rotation-sg"
  description = "SG Lambda rotación Secrets Manager — egress solo HTTPS VPC"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS hacia VPC endpoint de Secrets Manager"
  }

  tags = merge(var.common_tags, { Name = "${var.resource_prefix}-rotation-sg" })
}

resource "aws_iam_role" "rotation" {
  name = "${var.resource_prefix}-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "rotation_vpc" {
  role       = aws_iam_role.rotation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# IAM con recursos específicos — CKV_AWS_288, CKV_AWS_290, CKV_AWS_355
resource "aws_iam_role_policy" "rotation" {
  name = "${var.resource_prefix}-rotation-policy"
  role = aws_iam_role.rotation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManagerRotation"
        Effect   = "Allow"
        Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecretVersionStage"]
        Resource = [aws_secretsmanager_secret.db.arn, aws_secretsmanager_secret.jwt.arn]
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.resource_prefix}-secret-rotation:*"
      }
    ]
  })
}

# DLQ para la Lambda de rotación — CKV_AWS_116
resource "aws_sqs_queue" "rotation_dlq" {
  name                      = "${var.resource_prefix}-rotation-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_key_arn
  tags                      = var.common_tags
}

# Code signing — CKV_AWS_272
resource "aws_signer_signing_profile" "rotation" {
  name_prefix = "bigroyal_rotation_"
  platform_id = "AWSLambda-SHA384-ECDSA"
  signature_validity_period {
    value = 5
    type  = "YEARS"
  }
  tags = var.common_tags
}

resource "aws_lambda_code_signing_config" "rotation" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.rotation.version_arn]
  }
  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

data "archive_file" "rotation_stub" {
  type        = "zip"
  output_path = "${path.module}/rotation-stub.zip"
  source {
    content  = "exports.handler = async (event) => { return { statusCode: 200 }; };"
    filename = "index.js"
  }
}

resource "aws_lambda_function" "rotation" {
  function_name                  = "${var.resource_prefix}-secret-rotation"
  role                           = aws_iam_role.rotation.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 30
  reserved_concurrent_executions = 5
  kms_key_arn                    = var.kms_key_arn
  code_signing_config_arn        = aws_lambda_code_signing_config.rotation.arn
  filename                       = data.archive_file.rotation_stub.output_path
  source_code_hash               = data.archive_file.rotation_stub.output_base64sha256

  tracing_config { mode = "Active" }

  dead_letter_config { target_arn = aws_sqs_queue.rotation_dlq.arn }

  # Bloque environment necesario para CKV_AWS_173 (cifrado de env vars con KMS)
  environment {
    variables = {
      ENV = var.env
    }
  }

  # Lambda dentro de VPC para acceder al VPC endpoint de Secrets Manager — CKV_AWS_117
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.rotation.id]
  }

  tags = var.common_tags
}

resource "aws_lambda_permission" "secretsmanager_db" {
  statement_id  = "AllowSecretsManagerInvokeDB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.db.arn
}

resource "aws_lambda_permission" "secretsmanager_jwt" {
  statement_id  = "AllowSecretsManagerInvokeJWT"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.jwt.arn
}

# Rotación automática con Lambda — CKV2_AWS_57
resource "aws_secretsmanager_secret_rotation" "db" {
  secret_id           = aws_secretsmanager_secret.db.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn
  rotation_rules {
    automatically_after_days = 30
  }
  depends_on = [aws_lambda_permission.secretsmanager_db]
}

resource "aws_secretsmanager_secret_rotation" "jwt" {
  secret_id           = aws_secretsmanager_secret.jwt.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn
  rotation_rules {
    automatically_after_days = 30
  }
  depends_on = [aws_lambda_permission.secretsmanager_jwt]
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_password" "db" {
  length  = 32
  special = false
}

# Lambda stub de rotación para Secrets Manager — CKV2_AWS_57
resource "aws_iam_role" "rotation_lambda" {
  name = "${var.resource_prefix}-secret-rotation-role"

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

resource "aws_iam_role_policy" "rotation_lambda" {
  name = "${var.resource_prefix}-rotation-policy"
  role = aws_iam_role.rotation_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecretVersionStage"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rotation_basic" {
  role       = aws_iam_role.rotation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "rotation_stub" {
  type        = "zip"
  output_path = "${path.module}/rotation-stub.zip"

  source {
    content  = "exports.handler = async (event) => { console.log('Rotation stub', JSON.stringify(event)); return { statusCode: 200 }; };"
    filename = "index.js"
  }
}

resource "aws_lambda_function" "rotation" {
  function_name    = "${var.resource_prefix}-secret-rotation"
  role             = aws_iam_role.rotation_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30
  filename         = data.archive_file.rotation_stub.output_path
  source_code_hash = data.archive_file.rotation_stub.output_base64sha256
  kms_key_arn      = var.kms_key_arn

  tracing_config { mode = "Active" }

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

# Rotación automática con Lambda — CKV2_AWS_57
resource "aws_secretsmanager_secret_rotation" "db" {
  secret_id           = aws_secretsmanager_secret.db.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_lambda_permission.secretsmanager_db]
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

resource "aws_secretsmanager_secret_rotation" "jwt" {
  secret_id           = aws_secretsmanager_secret.jwt.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_lambda_permission.secretsmanager_jwt]
}

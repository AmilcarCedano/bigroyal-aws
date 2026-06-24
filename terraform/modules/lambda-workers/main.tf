locals {
  vpc_policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  sqs_policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# SG compartido para los workers — CKV_AWS_382, CKV2_AWS_5
resource "aws_security_group" "workers" {
  name        = "${var.resource_prefix}-workers-sg"
  description = "SG Lambda Workers — egress solo hacia VPC"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS hacia VPC endpoints (Secrets Manager, KMS, SQS)"
  }
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL hacia Aurora"
  }

  tags = merge(var.common_tags, { Name = "${var.resource_prefix}-workers-sg" })
}

resource "aws_sqs_queue" "workers_dlq" {
  name                      = "${var.resource_prefix}-workers-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_key_arn
  tags                      = var.common_tags
}

# Firma de código Lambda compartida para workers — CKV_AWS_272
resource "aws_signer_signing_profile" "workers" {
  name_prefix = "bigroyal_workers_"
  platform_id = "AWSLambda-SHA384-ECDSA"

  signature_validity_period {
    value = 5
    type  = "YEARS"
  }

  tags = var.common_tags
}

resource "aws_lambda_code_signing_config" "workers" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.workers.version_arn]
  }
  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

resource "aws_iam_role" "audit" {
  name = "${var.resource_prefix}-audit-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "audit_vpc" {
  role = aws_iam_role.audit.name; policy_arn = local.vpc_policy_arn
}
resource "aws_iam_role_policy_attachment" "audit_sqs" {
  role = aws_iam_role.audit.name; policy_arn = local.sqs_policy_arn
}
resource "aws_iam_role_policy" "audit_secrets" {
  name = "${var.resource_prefix}-audit-policy"
  role = aws_iam_role.audit.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [var.db_secret_arn] }]
  })
}

resource "aws_iam_role" "alertas_ops" {
  name = "${var.resource_prefix}-alertas-ops-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "alertas_vpc" {
  role = aws_iam_role.alertas_ops.name; policy_arn = local.vpc_policy_arn
}
resource "aws_iam_role_policy_attachment" "alertas_sqs" {
  role = aws_iam_role.alertas_ops.name; policy_arn = local.sqs_policy_arn
}
resource "aws_iam_role_policy" "alertas_ses" {
  name = "${var.resource_prefix}-alertas-ops-policy"
  role = aws_iam_role.alertas_ops.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["ses:SendEmail", "ses:SendRawEmail"], Resource = "*" }]
  })
}

resource "aws_iam_role" "process" {
  name = "${var.resource_prefix}-process-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "process_vpc" {
  role = aws_iam_role.process.name; policy_arn = local.vpc_policy_arn
}
resource "aws_iam_role_policy_attachment" "process_sqs" {
  role = aws_iam_role.process.name; policy_arn = local.sqs_policy_arn
}
resource "aws_iam_role_policy" "process_secrets" {
  name = "${var.resource_prefix}-process-policy"
  role = aws_iam_role.process.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [var.db_secret_arn] }]
  })
}

data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/worker-placeholder.zip"
  source {
    content  = "exports.handler = async (event) => { return { statusCode: 200 }; };"
    filename = "index.js"
  }
}

resource "aws_lambda_function" "audit" {
  function_name                  = "${var.resource_prefix}-lambda-audit"
  role                           = aws_iam_role.audit.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = 50
  kms_key_arn                    = var.kms_key_arn
  code_signing_config_arn        = aws_lambda_code_signing_config.workers.arn
  filename                       = data.archive_file.placeholder.output_path
  source_code_hash               = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      NODE_ENV      = var.env
      DB_SECRET_ARN = var.db_secret_arn
    }
  }

  tracing_config { mode = "Active" }
  dead_letter_config { target_arn = aws_sqs_queue.workers_dlq.arn }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.workers.id]
  }

  tags = var.common_tags
}

resource "aws_lambda_function" "alertas_ops" {
  function_name                  = "${var.resource_prefix}-lambda-alertas-ops"
  role                           = aws_iam_role.alertas_ops.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 50
  kms_key_arn                    = var.kms_key_arn
  code_signing_config_arn        = aws_lambda_code_signing_config.workers.arn
  filename                       = data.archive_file.placeholder.output_path
  source_code_hash               = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      NODE_ENV         = var.env
      SES_SENDER_EMAIL = var.ses_sender_email
    }
  }

  tracing_config { mode = "Active" }
  dead_letter_config { target_arn = aws_sqs_queue.workers_dlq.arn }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.workers.id]
  }

  tags = var.common_tags
}

resource "aws_lambda_function" "process" {
  function_name                  = "${var.resource_prefix}-lambda-process"
  role                           = aws_iam_role.process.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 60
  memory_size                    = 512
  reserved_concurrent_executions = 50
  kms_key_arn                    = var.kms_key_arn
  code_signing_config_arn        = aws_lambda_code_signing_config.workers.arn
  filename                       = data.archive_file.placeholder.output_path
  source_code_hash               = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      NODE_ENV      = var.env
      DB_SECRET_ARN = var.db_secret_arn
    }
  }

  tracing_config { mode = "Active" }
  dead_letter_config { target_arn = aws_sqs_queue.workers_dlq.arn }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.workers.id]
  }

  tags = var.common_tags
}

resource "aws_lambda_event_source_mapping" "audit" {
  event_source_arn = var.auditoria_financiera_queue_arn
  function_name    = aws_lambda_function.audit.arn
  batch_size       = 10
  enabled          = true
}

resource "aws_lambda_event_source_mapping" "alertas_ops" {
  event_source_arn = var.alertas_ops_queue_arn
  function_name    = aws_lambda_function.alertas_ops.arn
  batch_size       = 10
  enabled          = true
}

resource "aws_lambda_event_source_mapping" "process" {
  event_source_arn = var.inventario_queue_arn
  function_name    = aws_lambda_function.process.arn
  batch_size       = 10
  enabled          = true
}

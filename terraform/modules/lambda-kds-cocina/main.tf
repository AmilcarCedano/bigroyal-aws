resource "aws_iam_role" "lambda" {
  name = "${var.resource_prefix}-kds-cocina-role"

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

resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# DLQ para mensajes fallidos del KDS
resource "aws_sqs_queue" "kds_dlq" {
  name                      = "${var.resource_prefix}-kds-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_key_arn
  tags                      = var.common_tags
}

data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/kds-placeholder.zip"

  source {
    content  = "exports.handler = async (event) => { console.log('KDS Cocina:', JSON.stringify(event)); return { statusCode: 200 }; };"
    filename = "index.js"
  }
}

resource "aws_lambda_function" "kds_cocina" {
  function_name                  = "${var.resource_prefix}-kds-cocina"
  role                           = aws_iam_role.lambda.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 10
  memory_size                    = 256
  reserved_concurrent_executions = 50
  kms_key_arn                    = var.kms_key_arn

  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      NODE_ENV   = var.env
      REDIS_HOST = var.redis_endpoint
    }
  }

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.kds_dlq.arn
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = var.common_tags
}

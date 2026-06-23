# IAM Role para la Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.resource_prefix}-lambda-role"

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

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permite a la Lambda enviar trazas a X-Ray (CKV_AWS_50)
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy" "secrets_and_sns" {
  name = "${var.resource_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.db_secret_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_topic_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.dlq.arn]
      }
    ]
  })
}

# Dead Letter Queue para invocaciones asíncronas fallidas (CKV_AWS_116)
resource "aws_sqs_queue" "dlq" {
  name                              = "${var.resource_prefix}-backend-dlq"
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
  message_retention_seconds         = 1209600 # 14 días

  tags = var.common_tags
}

# Zip placeholder — cada integrante sube el código real al S3 o via CI
data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/placeholder.zip"

  source {
    content  = "exports.handler = async () => ({ statusCode: 200, body: 'ok' });"
    filename = "index.js"
  }
}

resource "aws_lambda_function" "this" {
  function_name                  = var.function_name
  role                           = aws_iam_role.lambda.arn
  handler                        = var.handler
  runtime                        = var.runtime
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  reserved_concurrent_executions = 100

  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  kms_key_arn = var.kms_key_arn

  # Trazado distribuido con AWS X-Ray (CKV_AWS_50)
  tracing_config {
    mode = "Active"
  }

  # Cola de mensajes muertos para invocaciones asíncronas fallidas (CKV_AWS_116)
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      NODE_ENV       = var.env
      DB_SECRET_ARN  = var.db_secret_arn
      REDIS_HOST     = var.redis_endpoint
      SNS_TOPIC_ARN  = var.sns_topic_arn
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = var.common_tags
}

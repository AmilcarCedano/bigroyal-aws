# SNS Topic FanOut — el backend publica aquí cuando confirma un pedido, cifrado KMS
resource "aws_sns_topic" "fanout" {
  name              = "${var.resource_prefix}-fanout"
  kms_master_key_id = var.kms_key_arn
  tags              = var.common_tags
}

# ─────────────────────────────────────────────
# Las 3 colas SQS del diagrama (RNF-09: retención 4 días)
# ─────────────────────────────────────────────

resource "aws_sqs_queue" "alertas_ops" {
  name                       = "${var.resource_prefix}-alertas-ops"
  message_retention_seconds  = 345600 # 4 días
  visibility_timeout_seconds = 60
  kms_master_key_id          = var.kms_key_arn
  tags                       = var.common_tags
}

resource "aws_sqs_queue" "auditoria_financiera" {
  name                       = "${var.resource_prefix}-auditoria-financiera"
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 60
  kms_master_key_id          = var.kms_key_arn
  tags                       = var.common_tags
}

resource "aws_sqs_queue" "inventario" {
  name                       = "${var.resource_prefix}-inventario"
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 60
  kms_master_key_id          = var.kms_key_arn
  tags                       = var.common_tags
}

# ─────────────────────────────────────────────
# Suscripciones SNS → cada cola SQS
# ─────────────────────────────────────────────

resource "aws_sns_topic_subscription" "alertas_ops" {
  topic_arn = aws_sns_topic.fanout.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.alertas_ops.arn
}

resource "aws_sns_topic_subscription" "auditoria" {
  topic_arn = aws_sns_topic.fanout.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.auditoria_financiera.arn
}

resource "aws_sns_topic_subscription" "inventario" {
  topic_arn = aws_sns_topic.fanout.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.inventario.arn
}

# ─────────────────────────────────────────────
# Políticas para que SNS pueda escribir en SQS
# ─────────────────────────────────────────────

locals {
  queues = {
    alertas_ops          = aws_sqs_queue.alertas_ops
    auditoria_financiera = aws_sqs_queue.auditoria_financiera
    inventario           = aws_sqs_queue.inventario
  }
}

resource "aws_sqs_queue_policy" "allow_sns" {
  for_each  = local.queues
  queue_url = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = each.value.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.fanout.arn } }
    }]
  })
}

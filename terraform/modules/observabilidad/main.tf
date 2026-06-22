# SNS Topic — notifica al equipo técnico (RNF-17: en <2 min), cifrado KMS (CKV_AWS_26)
resource "aws_sns_topic" "alerts" {
  name              = "${var.resource_prefix}-alertas-equipo"
  kms_master_key_id = var.kms_key_arn
  tags              = var.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ─────────────────────────────────────────────
# Alarma de tasa de errores por Lambda (RNF-17: >1% errores en ventana 5 min)
# Usa expresión métrica Errors/Invocations para calcular porcentaje real
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${each.key}-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 1   # 1% de tasa de errores
  alarm_description   = "Tasa de errores Lambda ${each.key} > 1% en 5 minutos — notifica en <2 min (RNF-17)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  # Expresión: (Errors / Invocations) * 100 > 1%
  metric_query {
    id          = "error_rate"
    expression  = "IF(invocations > 0, (errors / invocations) * 100, 0)"
    label       = "Tasa de errores (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300  # ventana de 5 minutos
      stat        = "Sum"
      dimensions  = { FunctionName = each.key }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions  = { FunctionName = each.key }
    }
  }

  tags = var.common_tags
}

# ─────────────────────────────────────────────
# Alarma de errores 5xx en API Gateway (RNF-05)
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  count = var.enable_api_5xx_alarm ? 1 : 0

  alarm_name          = "${var.resource_prefix}-api-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Errores 5xx en API Gateway > 10 en 5 minutos"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = { ApiId = var.api_gateway_api_id }

  tags = var.common_tags
}

# ─────────────────────────────────────────────
# Log group centralizado (RNF-18: logs JSON 30 días)
# ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/bigroyal/${var.env}/backend"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
  tags              = var.common_tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.resource_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "Errores Lambda (todas las funciones)"
          period = 300
          stat   = "Sum"
          metrics = [
            for fn in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", fn]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "Invocaciones Lambda"
          period = 300
          stat   = "Sum"
          metrics = [
            for fn in var.lambda_function_names : ["AWS/Lambda", "Invocations", "FunctionName", fn]
          ]
        }
      }
    ]
  })
}

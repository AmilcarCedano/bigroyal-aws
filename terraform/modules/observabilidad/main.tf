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

# ─────────────────────────────────────────────
# METRIC FILTERS — convierten los LOGS del sistema en métricas graficables.
# Este es el puente logs → indicadores de dashboard: cada patrón barre un
# log group en tiempo real y publica una métrica custom en BigRoyal/<env>.
# ─────────────────────────────────────────────

locals {
  metric_namespace  = "BigRoyal/${var.env}"
  aurora_cluster_id = "${var.resource_prefix}-aurora-cluster"
  redis_cluster_id  = "${var.resource_prefix}-redis"

  # Paleta de colores de los dashboards (consistente entre widgets)
  color_ok      = "#2ca02c" # verde  — tráfico normal / hits
  color_error   = "#d62728" # rojo   — errores / bloqueos
  color_warn    = "#ff7f0e" # naranja— latencia / misses
  color_info    = "#1f77b4" # azul   — peticiones / conexiones
  color_neutral = "#9467bd" # morado — métricas secundarias
}

# Errores reales que escribe la aplicación en sus logs (console.error del backend)
resource "aws_cloudwatch_log_metric_filter" "backend_errores" {
  name           = "${var.resource_prefix}-errores-backend"
  log_group_name = var.backend_log_group_name
  pattern        = "ERROR"

  metric_transformation {
    name          = "ErroresBackend"
    namespace     = local.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

# Respuestas 5xx extraídas del access log JSON del API Gateway
resource "aws_cloudwatch_log_metric_filter" "api_5xx_logs" {
  name           = "${var.resource_prefix}-api-5xx-logs"
  log_group_name = var.api_access_log_group_name
  pattern        = "{ $.status = \"5*\" }"

  metric_transformation {
    name          = "Peticiones5xx"
    namespace     = local.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

# Peticiones bloqueadas por el WAF, extraídas de sus logs
resource "aws_cloudwatch_log_metric_filter" "waf_bloqueos" {
  name           = "${var.resource_prefix}-waf-bloqueos"
  log_group_name = var.waf_log_group_name
  pattern        = "{ $.action = \"BLOCK\" }"

  metric_transformation {
    name          = "WAFBloqueos"
    namespace     = local.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

# ─────────────────────────────────────────────
# DASHBOARD 1 — API y Aplicación
# KPIs de tráfico + errores desde LOGS + tabla en vivo de peticiones
# ─────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "api" {
  dashboard_name = "${var.resource_prefix}-1-api-aplicacion"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 1
        properties = { markdown = "# 🚦 BigRoyal — API y Aplicación · tráfico, errores y logs en vivo" }
      },
      {
        type = "metric", x = 0, y = 1, width = 6, height = 4
        properties = {
          title = "Peticiones a la API", view = "singleValue", sparkline = true
          region = var.aws_region, period = 300, stat = "Sum"
          metrics = [["AWS/ApiGateway", "Count", "ApiId", var.api_gateway_api_id, { color = local.color_info, label = "peticiones" }]]
        }
      },
      {
        type = "metric", x = 6, y = 1, width = 6, height = 4
        properties = {
          title = "Errores 5xx", view = "singleValue", sparkline = true
          region = var.aws_region, period = 300, stat = "Sum"
          metrics = [["AWS/ApiGateway", "5xx", "ApiId", var.api_gateway_api_id, { color = local.color_error, label = "errores 5xx" }]]
        }
      },
      {
        type = "metric", x = 12, y = 1, width = 6, height = 4
        properties = {
          title = "Latencia promedio (ms)", view = "singleValue", sparkline = true
          region = var.aws_region, period = 300, stat = "Average"
          metrics = [["AWS/ApiGateway", "Latency", "ApiId", var.api_gateway_api_id, { color = local.color_warn, label = "ms" }]]
        }
      },
      {
        type = "metric", x = 18, y = 1, width = 6, height = 4
        properties = {
          title = "📋 Errores en LOGS del backend", view = "singleValue", sparkline = true
          region = var.aws_region, period = 300, stat = "Sum"
          metrics = [[local.metric_namespace, "ErroresBackend", { color = local.color_error, label = "errores (logs)" }]]
        }
      },
      {
        type = "metric", x = 0, y = 5, width = 12, height = 6
        properties = {
          title = "Invocaciones por Lambda", view = "timeSeries", stacked = false
          region = var.aws_region, period = 300, stat = "Sum"
          metrics = [
            for fn in var.lambda_function_names : ["AWS/Lambda", "Invocations", "FunctionName", fn, { label = fn }]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 5, width = 12, height = 6
        properties = {
          title = "Errores por Lambda + errores en logs (📋 metric filter)", view = "timeSeries", stacked = false
          region = var.aws_region, period = 300, stat = "Sum"
          metrics = concat(
            [for fn in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", fn, { label = "Errors ${fn}" }]],
            [[local.metric_namespace, "ErroresBackend", { color = local.color_error, label = "📋 ERROR en logs backend" }], [local.metric_namespace, "Peticiones5xx", { color = local.color_warn, label = "📋 5xx en access logs" }]]
          )
        }
      },
      {
        type = "log", x = 0, y = 11, width = 24, height = 6
        properties = {
          title  = "📋 Últimas peticiones al API (access log en vivo: ruta, status, IP)"
          region = var.aws_region
          query  = "SOURCE '${var.api_access_log_group_name}' | fields @timestamp, routeKey, status, ip, responseLength | sort @timestamp desc | limit 20"
          view   = "table"
        }
      },
      {
        type = "log", x = 0, y = 17, width = 24, height = 6
        properties = {
          title  = "📋 Últimos errores registrados por la aplicación (logs del backend)"
          region = var.aws_region
          query  = "SOURCE '${var.backend_log_group_name}' | filter @message like /ERROR/ | fields @timestamp, @message | sort @timestamp desc | limit 20"
          view   = "table"
        }
      }
    ]
  })
}

# ─────────────────────────────────────────────
# DASHBOARD 2 — Base de Datos y Caché
# ─────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "datos" {
  dashboard_name = "${var.resource_prefix}-2-datos"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 1
        properties = { markdown = "# 🗄️ BigRoyal — Base de Datos (Aurora) y Caché (Redis)" }
      },
      {
        type = "metric", x = 0, y = 1, width = 6, height = 6
        properties = {
          title = "CPU Aurora (%)", view = "gauge"
          region = var.aws_region, period = 300, stat = "Average"
          yAxis = { left = { min = 0, max = 100 } }
          metrics = [["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", local.aurora_cluster_id, { color = local.color_info, label = "CPU %" }]]
        }
      },
      {
        type = "metric", x = 6, y = 1, width = 9, height = 6
        properties = {
          title = "Conexiones a la base de datos", view = "timeSeries"
          region = var.aws_region, period = 300, stat = "Sum"
          metrics = [["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", local.aurora_cluster_id, { color = local.color_info, label = "conexiones" }]]
        }
      },
      {
        type = "metric", x = 15, y = 1, width = 9, height = 6
        properties = {
          title = "Latencia de lectura vs escritura (ms)", view = "timeSeries"
          region = var.aws_region, period = 300, stat = "Average"
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBClusterIdentifier", local.aurora_cluster_id, { color = local.color_ok, label = "lectura" }],
            ["AWS/RDS", "WriteLatency", "DBClusterIdentifier", local.aurora_cluster_id, { color = local.color_warn, label = "escritura" }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 7, width = 6, height = 6
        properties = {
          title = "CPU Redis (%)", view = "gauge"
          region = var.aws_region, period = 300, stat = "Average"
          yAxis = { left = { min = 0, max = 100 } }
          metrics = [["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", local.redis_cluster_id, { color = local.color_neutral, label = "CPU %" }]]
        }
      },
      {
        type = "metric", x = 6, y = 7, width = 9, height = 6
        properties = {
          title = "Caché: hits (verde) vs misses (rojo)", view = "timeSeries"
          region = var.aws_region, period = 300, stat = "Sum"
          metrics = [
            ["AWS/ElastiCache", "CacheHits", "CacheClusterId", local.redis_cluster_id, { color = local.color_ok, label = "hits" }],
            ["AWS/ElastiCache", "CacheMisses", "CacheClusterId", local.redis_cluster_id, { color = local.color_error, label = "misses" }]
          ]
        }
      },
      {
        type = "metric", x = 15, y = 7, width = 9, height = 6
        properties = {
          title = "Conexiones activas a Redis", view = "timeSeries"
          region = var.aws_region, period = 300, stat = "Average"
          metrics = [["AWS/ElastiCache", "CurrConnections", "CacheClusterId", local.redis_cluster_id, { color = local.color_neutral, label = "conexiones" }]]
        }
      },
      {
        type = "log", x = 0, y = 13, width = 24, height = 6
        properties = {
          title  = "📋 Logs de PostgreSQL (errores y avisos del motor de la BD)"
          region = var.aws_region
          query  = "SOURCE '/aws/rds/cluster/${local.aurora_cluster_id}/postgresql' | filter @message like /ERROR|FATAL|WARNING/ | fields @timestamp, @message | sort @timestamp desc | limit 20"
          view   = "table"
        }
      }
    ]
  })
}

# ─────────────────────────────────────────────
# DASHBOARD 3 — Seguridad y Edge
# ─────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "seguridad" {
  dashboard_name = "${var.resource_prefix}-3-seguridad"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 1
        properties = { markdown = "# 🛡️ BigRoyal — Seguridad (WAF) y Edge (CloudFront)" }
      },
      {
        type = "metric", x = 0, y = 1, width = 6, height = 4
        properties = {
          title = "📋 Bloqueos del WAF (desde logs)", view = "singleValue", sparkline = true
          region = var.aws_region, period = 300, stat = "Sum"
          metrics = [[local.metric_namespace, "WAFBloqueos", { color = local.color_error, label = "bloqueadas" }]]
        }
      },
      {
        type = "metric", x = 6, y = 1, width = 9, height = 4
        properties = {
          title = "Peticiones a CloudFront", view = "timeSeries"
          region = "us-east-1", period = 300, stat = "Sum"
          metrics = [["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { color = local.color_info, label = "requests" }]]
        }
      },
      {
        type = "metric", x = 15, y = 1, width = 9, height = 4
        properties = {
          title = "Tasa de error en CloudFront (%)", view = "timeSeries"
          region = "us-east-1", period = 300, stat = "Average"
          yAxis = { left = { min = 0 } }
          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { color = local.color_warn, label = "4xx %" }],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { color = local.color_error, label = "5xx %" }]
          ]
        }
      },
      {
        type = "log", x = 0, y = 5, width = 12, height = 6
        properties = {
          title  = "📋 Ataques bloqueados por regla del WAF (desde sus logs)"
          region = var.aws_region
          query  = "SOURCE '${var.waf_log_group_name}' | filter action = \"BLOCK\" | stats count(*) as bloqueos by terminatingRuleId | sort bloqueos desc"
          view   = "table"
        }
      },
      {
        type = "log", x = 12, y = 5, width = 12, height = 6
        properties = {
          title  = "📋 Top 10 rutas más consultadas (access logs del API)"
          region = var.aws_region
          query  = "SOURCE '${var.api_access_log_group_name}' | stats count(*) as peticiones by routeKey | sort peticiones desc | limit 10"
          view   = "table"
        }
      }
    ]
  })
}

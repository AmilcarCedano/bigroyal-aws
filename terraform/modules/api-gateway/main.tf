resource "aws_apigatewayv2_api" "this" {
  name          = "${var.resource_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = var.common_tags
}

# Integración Lambda
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_arn
  payload_format_version = "2.0"
}

# Authorizer JWT con Cognito — el frontend se autentica directo contra
# Cognito (InitiateAuth desde el navegador) y envía el ID token como Bearer.
# API Gateway verifica firma, emisor, audiencia y expiración ANTES de
# invocar la Lambda; el backend solo lee los claims ya validados.
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.resource_prefix}-jwt-authorizer"

  jwt_configuration {
    audience = [var.cognito_app_client_id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

# Todas las rutas de la API exigen un token válido de Cognito.
resource "aws_apigatewayv2_route" "proxy" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# Preflight OPTIONS — el navegador nunca envía Authorization en el preflight,
# así que esta ruta debe responder sin exigir JWT o el CORS muere antes de empezar.
resource "aws_apigatewayv2_route" "options_preflight" {
  #checkov:skip=CKV_AWS_309:Preflight CORS — solo responde headers, nunca ejecuta lógica de negocio
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "OPTIONS /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorization_type = "NONE"
}

# Log group para el access logging del API Gateway (cifrado KMS + retención 1 año)
resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${var.resource_prefix}-api"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = var.common_tags
}

# Stage auto-deploy con access logging habilitado (CKV_AWS_76)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = var.common_tags
}

# Permiso para que API Gateway invoque la Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

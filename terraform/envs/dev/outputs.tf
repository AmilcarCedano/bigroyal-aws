output "url_frontend" {
  description = "URL del frontend (Route 53 → CloudFront)"
  value       = "https://${var.domain_name}"
}

output "cloudfront_url" {
  description = "URL directa de CloudFront (sin dominio propio)"
  value       = "https://${module.cloudfront.cdn_domain_name}"
}

output "api_gateway_url" {
  description = "URL base del API Gateway (backend)"
  value       = module.api_gateway.api_url
}

output "cognito_user_pool_id"  { value = module.cognito.user_pool_id }
output "cognito_app_client_id" { value = module.cognito.app_client_id }

output "aurora_endpoint" {
  value     = module.aurora.cluster_endpoint
  sensitive = true
}

output "redis_endpoint" {
  value     = module.redis.endpoint
  sensitive = true
}

output "route53_name_servers" {
  description = "Name servers de Route 53 — apuntar el dominio a estos"
  value       = module.route53.name_servers
}

output "kms_key_arn" {
  description = "ARN de la clave KMS (Aurora + S3)"
  value       = module.kms.key_arn
}

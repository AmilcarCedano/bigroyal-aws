output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
  description = "Nombre de dominio de la distribucion de CloudFront"
}
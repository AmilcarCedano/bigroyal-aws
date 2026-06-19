output "bucket_regional_domain_name" {
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
  description = "Nombre de dominio regional del bucket S3"
}
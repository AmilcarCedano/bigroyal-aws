variable "bucket_regional_domain_name" {
  type        = string
  description = "Nombre de dominio regional del bucket S3 de origen"
}

variable "common_tags" {
  type        = map(string)
  description = "Etiquetas comunes para los recursos"
}
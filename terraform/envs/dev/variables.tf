variable "project_name" {
  description = "Nombre base del proyecto"
  type        = string
}
variable "env" {
  description = "Entorno (dev, staging, prod)"
  type        = string
}
variable "aws_region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}
variable "resource_prefix" {
  description = "Prefijo para nombres de recursos (ej: bigroyal-dev)"
  type        = string
}
variable "alarm_email" {
  description = "Email para alertas de CloudWatch"
  type        = string
}
variable "ses_sender_email" {
  description = "Email verificado en SES para alertas críticas"
  type        = string
}
variable "domain_name" {
  description = "Dominio principal del sistema"
  type        = string
  default     = "bigroyal.com"
}
variable "db_name" {
  description = "Nombre de la base de datos Aurora"
  type        = string
  default     = "bigroyal"
}
variable "db_master_username" {
  description = "Usuario master de Aurora"
  type        = string
  sensitive   = true
  default     = "bigroyaladmin"
}
variable "aurora_deletion_protection" {
  description = "Protección contra borrado del cluster Aurora (false en dev, true en prod)"
  type        = bool
}

variable "project_name"                   { type = string }
variable "env"                            { type = string }
variable "resource_prefix"                { type = string }
variable "common_tags"                    { type = map(string) }
variable "subnet_ids"                     { type = list(string) }
variable "vpc_id"                         { type = string }
variable "vpc_cidr"                       { type = string }
variable "db_secret_arn"                  { type = string }
variable "kms_key_arn"                    { type = string }
variable "alertas_ops_queue_arn"          { type = string }
variable "auditoria_financiera_queue_arn" { type = string }
variable "inventario_queue_arn"           { type = string }
variable "ses_sender_email"               { type = string; default = "alertas@bigroyal.com" }

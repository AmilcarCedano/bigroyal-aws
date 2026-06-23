variable "project_name"       { type = string }
variable "env"                { type = string }
variable "resource_prefix"    { type = string }
variable "common_tags"        { type = map(string) }
variable "function_name"      { type = string }
variable "handler"            { type = string; default = "index.handler" }
variable "runtime"            { type = string; default = "nodejs20.x" }
variable "timeout"            { type = number; default = 30 }
variable "memory_size"        { type = number; default = 512 }
variable "db_secret_arn"      { type = string }
variable "redis_endpoint"     { type = string }
variable "sns_topic_arn"      { type = string }
variable "subnet_ids"         { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "kms_key_arn"        { type = string } # ARN KMS para cifrar variables de entorno y DLQ de la Lambda
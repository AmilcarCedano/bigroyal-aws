variable "project_name"       { type = string }
variable "env"                { type = string }
variable "resource_prefix"    { type = string }
variable "common_tags"        { type = map(string) }
variable "subnet_ids"         { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "redis_endpoint"     { type = string }
variable "kms_key_arn"        { type = string }

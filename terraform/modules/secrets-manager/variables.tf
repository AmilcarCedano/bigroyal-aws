variable "project_name"       { type = string }
variable "env"                { type = string }
variable "resource_prefix"    { type = string }
variable "common_tags"        { type = map(string) }
variable "db_name"            { type = string }
variable "db_master_username" { type = string; sensitive = true }
variable "kms_key_arn"        { type = string }

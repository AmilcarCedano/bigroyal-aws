variable "project_name"       { type = string }
variable "env"                { type = string }
variable "resource_prefix"    { type = string }
variable "common_tags"        { type = map(string) }
variable "aurora_cluster_arn" { type = string }
variable "kms_key_arn"        { type = string }

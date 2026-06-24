variable "project_name"    { type = string }
variable "env"             { type = string }
variable "resource_prefix" { type = string }
variable "common_tags"     { type = map(string) }
variable "kms_key_arn"      { type = string }
variable "sns_topic_arn"   { type = string; default = "" }
variable "replica_region"  { type = string; default = "us-west-2" }

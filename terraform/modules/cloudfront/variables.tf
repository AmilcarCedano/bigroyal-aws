variable "project_name"       { type = string }
variable "env"                { type = string }
variable "resource_prefix"    { type = string }
variable "aws_region"         { type = string }
variable "common_tags"        { type = map(string) }
variable "s3_bucket_id"       { type = string }
variable "s3_bucket_arn"      { type = string }
variable "origin_domain_name" { type = string }
variable "web_acl_arn"        { type = string }
variable "kms_key_arn"        { type = string }
variable "price_class"           { type = string; default = "PriceClass_100" }
variable "acm_certificate_arn"  { type = string }

variable "project_name"          { type = string }
variable "env"                   { type = string }
variable "resource_prefix"       { type = string }
variable "common_tags"           { type = map(string) }
variable "alarm_email"           { type = string }
variable "kms_key_arn"           { type = string }
variable "lambda_function_names" { type = list(string) }
variable "api_gateway_api_id"    { type = string }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "enable_api_5xx_alarm" {
  type    = bool
  default = true
}
variable "backend_log_group_name"    { type = string }
variable "api_access_log_group_name" { type = string }
variable "waf_log_group_name"        { type = string }
variable "cloudfront_distribution_id" { type = string }

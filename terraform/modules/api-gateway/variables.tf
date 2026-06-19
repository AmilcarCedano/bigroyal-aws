variable "project_name"          { type = string }
variable "env"                   { type = string }
variable "resource_prefix"       { type = string }
variable "aws_region"            { type = string }
variable "common_tags"           { type = map(string) }
variable "lambda_arn"            { type = string }
variable "cognito_user_pool_id"  { type = string }
variable "cognito_app_client_id" { type = string }

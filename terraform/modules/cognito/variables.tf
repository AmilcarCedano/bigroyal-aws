variable "project_name"       { type = string }
variable "env"                { type = string }
variable "resource_prefix"    { type = string }
variable "aws_region"         { type = string }
variable "common_tags"        { type = map(string) }
variable "oauth_callback_url" { type = string }
variable "oauth_logout_url"   { type = string }

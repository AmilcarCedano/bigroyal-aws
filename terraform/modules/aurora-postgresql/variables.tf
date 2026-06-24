variable "project_name"       { type = string }
variable "env"                { type = string }
variable "resource_prefix"    { type = string }
variable "aws_region"         { type = string }
variable "common_tags"        { type = map(string) }
variable "db_name"            { type = string }
variable "db_master_username" {
  type      = string
  sensitive = true
}
variable "db_master_password" {
  type      = string
  sensitive = true
}
variable "kms_key_arn"    { type = string }
variable "subnet_ids"     { type = list(string) }
variable "vpc_id"         { type = string }
variable "vpc_cidr"       { type = string }
variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}
variable "engine_version" {
  type    = string
  default = "15.8"
}
variable "backup_plan_id"  { type = string }
variable "backup_role_arn" { type = string }
variable "deletion_protection" {
  type    = bool
  default = true
}

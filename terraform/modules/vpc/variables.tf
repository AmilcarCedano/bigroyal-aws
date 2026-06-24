variable "project_name"    { type = string }
variable "env"             { type = string }
variable "resource_prefix" { type = string }
variable "aws_region"      { type = string }
variable "common_tags"     { type = map(string) }
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "private_subnet_a_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
variable "private_subnet_b_cidr" {
  type    = string
  default = "10.0.2.0/24"
}
variable "public_subnet_cidr" {
  type    = string
  default = "10.0.10.0/24"
}
variable "kms_key_arn" { type = string }

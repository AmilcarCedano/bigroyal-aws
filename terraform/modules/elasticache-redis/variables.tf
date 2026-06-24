variable "project_name"    { type = string }
variable "env"             { type = string }
variable "resource_prefix" { type = string }
variable "common_tags"     { type = map(string) }
variable "subnet_ids"      { type = list(string) }
variable "vpc_id"          { type = string }
variable "vpc_cidr"        { type = string }
variable "node_type"       { type = string; default = "cache.t3.micro" }
variable "num_cache_nodes" { type = number; default = 1 }

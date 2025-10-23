variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "environment" {}
variable "allow_ssh_from" { type = string }

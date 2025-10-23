variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "ami_id" {}
variable "key_name" {}
variable "instance_size" {}
variable "instance_sg_id" {}
variable "alb_sg_id" {}
variable "ansible_repo_url" {}
variable "desired_capacity" { type = number }
variable "min_size" { type = number }
variable "max_size" { type = number }

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "instance_size" {
  type    = string
  default = "t3.medium"
}

variable "allow_ssh_from" {
  description = "CIDR allowed to SSH to instances (default 0.0.0.0/0 like original)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "ansible_repo_url" {
  description = "Git repository URL for Ansible playbooks"
  type        = string
  default     = "https://github.com/MD4HASH/portfolio"
}

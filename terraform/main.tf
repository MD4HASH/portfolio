
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.17"
    }

  }

  backend "s3" {
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}




data "aws_caller_identity" "current" {}


module "prerequisites" {
  source = "./modules/prerequisites"
}

# Create a private key to access the management server

resource "tls_private_key" "aws_admin_key" {
  algorithm = "RSA"
}

# Save private file in secrets directory (ensure "secrets/*" is included in .gitignore)
resource "local_file" "aws_admin_private_key_pem" {
  content  = tls_private_key.aws_admin_key.private_key_pem
  filename = "../secrets/aws_admin_key.pem"
}

resource "null_resource" "null_provisioner" {
  triggers = {
    key_file = local_file.aws_admin_private_key_pem.filename
  }

  provisioner "local-exec" {
    command = "chmod 600 ${local_file.aws_admin_private_key_pem.filename}"
  }
}



# Create keypair in aws
resource "aws_key_pair" "aws_admin_key" {
  key_name   = "aws_admin_key"
  public_key = tls_private_key.aws_admin_key.public_key_openssh
}


# Look up current avaialbility zones

data "aws_availability_zones" "available" {
  state = "available"
}
# look up latest ubuntu version for EC2 instances
# Took this from, https://github.com/btkrausen/hashicorp/blob/master/terraform/Hands-On%20Labs/Section%2004%20-%20Understand%20Terraform%20Basics/08%20-%20Intro_to_the_Terraform_Data_Block.md#step-511

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical’s official AWS account ID
}
# --- network
module "network" {
  source               = "./modules/network"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
}

# --- security (SGs)
module "security" {
  source         = "./modules/security"
  vpc_id         = module.network.vpc_id
  public_subnets = module.network.public_subnets
  environment    = var.environment
  allow_ssh_from = var.allow_ssh_from
}

# --- compute (ASG + LT + ALB)
module "compute" {
  source           = "./modules/compute"
  vpc_id           = module.network.vpc_id
  public_subnets   = module.network.public_subnets
  ami_id           = data.aws_ami.ubuntu.id
  key_name         = aws_key_pair.aws_admin_key.key_name
  instance_size    = var.instance_size
  instance_sg_id   = module.security.instance_sg_id
  alb_sg_id        = module.security.alb_sg_id
  ansible_repo_url = var.ansible_repo_url
  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size
}


module "config" {
  source      = "./modules/config"
  account_id  = data.aws_caller_identity.current.account_id
  environment = var.environment
}

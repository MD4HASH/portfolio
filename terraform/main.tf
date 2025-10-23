
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



# # Security Groups

# resource "aws_security_group" "ingress-ssh" {
#   name   = "allow-all-ssh"
#   vpc_id = module.main.vpc_id
#   # SSH
#   ingress {
#     description = "Allow SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # Web UI
#   ingress {
#     description = "Allow Text-Generation-WebUI"
#     from_port   = 7860
#     to_port     = 7860
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }


#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# module "main" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "6.4.0"

#   name = "main-vpc"
#   cidr = var.vpc_cidr
#   azs  = slice(data.aws_availability_zones.available.names, 0, 3)


#   public_subnets  = var.public_subnet_cidrs
#   private_subnets = var.private_subnet_cidrs

#   enable_nat_gateway = true
#   single_nat_gateway = true

#   enable_flow_log                                 = true
#   flow_log_destination_type                       = "cloud-watch-logs"
#   create_flow_log_cloudwatch_iam_role             = true
#   create_flow_log_cloudwatch_log_group            = true
#   flow_log_cloudwatch_log_group_name_prefix       = "/aws/vpc/flowlogs/"
#   flow_log_cloudwatch_log_group_retention_in_days = 30
#   flow_log_max_aggregation_interval               = 60

#   tags = {
#     Environment = "Production"
#     Name        = "prod-main-vpc"
#   }
# }


# resource "aws_instance" "main_vsi" {
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = var.instance_size
#   subnet_id                   = module.main.public_subnets[0]
#   vpc_security_group_ids      = [aws_security_group.ingress-ssh.id]
#   associate_public_ip_address = true
#   key_name                    = aws_key_pair.aws_admin_key.key_name

#   root_block_device {
#     volume_size = 50
#     volume_type = "gp3"
#   }

#   tags = {
#     Name = "webui-server"
#   }

#   provisioner "local-exec" {
#     command = "chmod 600 ${local_file.aws_admin_private_key_pem.filename}"
#   }
# }

# # Separate EBS volume for models
# resource "aws_ebs_volume" "webui_models" {
#   availability_zone = aws_instance.main_vsi.availability_zone
#   size              = 100
#   type              = "gp3"

#   tags = {
#     Name = "webui-models"
#   }
# }

# # Attach the EBS volume to the instance
# resource "aws_volume_attachment" "webui_models_attach" {
#   device_name = "/dev/sdf"
#   volume_id   = aws_ebs_volume.webui_models.id
#   instance_id = aws_instance.main_vsi.id
# }


# ### AWS config

# # Enable AWS Config
# resource "aws_config_configuration_recorder" "main" {
#   name     = "config-recorder"
#   role_arn = aws_iam_role.config_role.arn

#   recording_group {
#     all_supported = true
#   }
# }

# resource "aws_iam_role" "config_role" {
#   name = "aws-config-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action    = "sts:AssumeRole"
#       Effect    = "Allow"
#       Principal = { Service = "config.amazonaws.com" }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "config_policy" {
#   role       = aws_iam_role.config_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
# }

# # Store configuration snapshots in S3
# resource "aws_s3_bucket" "config_bucket" {
#   bucket = "aws-config-${data.aws_caller_identity.current.account_id}"
# }

# resource "aws_config_delivery_channel" "main" {
#   name           = "config-delivery"
#   s3_bucket_name = aws_s3_bucket.config_bucket.bucket
#   depends_on     = [aws_config_configuration_recorder.main]
# }

# # Start recording
# resource "aws_config_configuration_recorder_status" "main" {
#   name       = aws_config_configuration_recorder.main.name
#   is_enabled = true
# }

# # Example managed Config rule: check that SSH (22) isn’t open to world
# resource "aws_config_config_rule" "restricted_ssh" {
#   name = "restricted-ssh"
#   source {
#     owner             = "AWS"
#     source_identifier = "INCOMING_SSH_DISABLED"
#   }
# }

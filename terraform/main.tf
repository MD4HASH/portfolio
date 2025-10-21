# terraform/main.tf
module "prerequisites" {
  source = "./prerequisites"
}

terraform {
  backend "s3" {
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
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

# Security Groups

resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-ssh"
  vpc_id = module.main.vpc_id
  # SSH
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Web UI
  ingress {
    description = "Allow Text-Generation-WebUI"
    from_port   = 7860
    to_port     = 7860
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "main" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.4.0"

  name = "main-vpc"
  cidr = var.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)


  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_flow_log                                 = true
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  flow_log_cloudwatch_log_group_name_prefix       = "/aws/vpc/flowlogs/"
  flow_log_cloudwatch_log_group_retention_in_days = 30
  flow_log_max_aggregation_interval               = 60

  tags = {
    Environment = "Production"
    Name        = "prod-main-vpc"
  }
}


resource "aws_instance" "main_vsi" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_size
  subnet_id                   = module.main.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ingress-ssh.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.aws_admin_key.key_name

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "webui-server"
  }

  provisioner "local-exec" {
    command = "chmod 600 ${local_file.aws_admin_private_key_pem.filename}"
  }
}

# Separate EBS volume for models
resource "aws_ebs_volume" "webui_models" {
  availability_zone = aws_instance.main_vsi.availability_zone
  size              = 100
  type              = "gp3"

  tags = {
    Name = "webui-models"
  }
}

# Attach the EBS volume to the instance
resource "aws_volume_attachment" "webui_models_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.webui_models.id
  instance_id = aws_instance.main_vsi.id
}

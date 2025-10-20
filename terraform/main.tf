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
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
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
  vpc_security_group_ids      = [aws_security_group.ingress-ssh.id, aws_security_group.boundary.id, aws_security_group.vault.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.aws_admin_key.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.aws_admin_key.private_key_pem
    host        = self.public_ip
  }

  provisioner "local-exec" {
    command = "chmod 600 ${local_file.aws_admin_private_key_pem.filename}"
  }
}

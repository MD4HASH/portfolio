# Security group for ALB (allow inbound 80)
resource "aws_security_group" "alb_sg" {
  name   = "${var.environment}-alb-sg"
  vpc_id = var.vpc_id

  description = "ALB security group - allow HTTP from internet"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-alb-sg" }
}

# Security group for instances - allow SSH from admin CIDR and HTTP from ALB
resource "aws_security_group" "instance_sg" {
  name   = "${var.environment}-instance-sg"
  vpc_id = var.vpc_id

  description = "Instance SG - allow SSH and traffic from ALB"

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allow_ssh_from]
  }

  ingress {
    description = "App port from ALB"
    from_port   = 7860
    to_port     = 7860
    protocol    = "tcp"
    # allow only from ALB SG (reference in compute module)
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-instance-sg" }
}

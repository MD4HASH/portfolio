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

resource "aws_launch_template" "webui_lt" {
  name_prefix   = "webui-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_size
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.instance_sg_id]
  }

  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(data.template_file.userdata.rendered)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "webui-asg-instance"
    }
  }
}


data "template_file" "userdata" {
  template = file("${path.module}/../../templates/ansible-userdata.sh")
  vars = {
    ansible_repo_url = var.ansible_repo_url
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "webui_asg" {
  name                = "webui-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.public_subnets

  launch_template {
    id      = aws_launch_template.webui_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "webui-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB
resource "aws_lb" "webui_alb" {
  name               = "webui-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets
}

resource "aws_lb_target_group" "webui_tg" {
  name     = "webui-tg"
  port     = 7860
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.webui_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webui_tg.arn
  }
}

# Attach ASG to Target Group
resource "aws_autoscaling_attachment" "asg_to_tg" {
  autoscaling_group_name = aws_autoscaling_group.webui_asg.name
  alb_target_group_arn   = aws_lb_target_group.webui_tg.arn
}

output "asg_name" {
  value = aws_autoscaling_group.webui_asg.name
}

output "lb_dns_name" {
  value = aws_lb.webui_alb.dns_name
}

output "lb_arn" {
  value = aws_lb.webui_alb.arn
}

output "asg_name" {
  value = aws_autoscaling_group.webui_asg.name
}

output "lb_dns_name" {
  value = aws_lb.webui_alb.dns_name
}

output "lb_arn" {
  value = aws_lb.webui_alb.arn
}

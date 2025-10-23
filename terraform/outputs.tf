output "alb_dns" {
  value = module.compute.lb_dns_name
}

output "asg_name" {
  value = module.compute.asg_name
}

output "private_key_path" {
  value = local_file.aws_admin_private_key_pem.filename
}


output "asg_public_ips_command" {
  description = "Run this command to get the public IPs of all EC2 instances in your ASG."
  value       = <<EOT
aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=${module.compute.asg_name}" \
  --query "Reservations[*].Instances[*].PublicIpAddress" \
  --output text
EOT
}

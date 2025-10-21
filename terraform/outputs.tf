output "server_public_ip" {
  value = aws_instance.main_vsi.public_ip
}

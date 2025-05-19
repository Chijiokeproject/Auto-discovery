output "nexus_ip" {
  value = aws_instance.nexus.public_ip
}
output "nexus_private_ip" {
  value = aws_instance.nexus.private_ip
}
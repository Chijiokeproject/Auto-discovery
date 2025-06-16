output "nexus_public_ip" {
  value = aws_instance.nexus.public_ip
}

output "nexus_ip" {
  value = aws_instance.nexus.private_ip
}



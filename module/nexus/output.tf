output "nexus_public_ip" {
  value = module.nexus.nexus_public_ip
}

output "nexus_private_ip" {
  value = aws_instance.nexus.private_ip
}
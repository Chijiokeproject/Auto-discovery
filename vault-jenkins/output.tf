output "vault_public_ip" {
  value = aws_instance.vault_server.public_ip
}
output "jenkins_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}
output "vault_public_ip" {
  value = aws_instance.vault_server.public_ip
}
#output "jenkins_public_ip" {
 # value = aws_instance.jenkins-server.public_ip
#}
output "sonarqube_public_ip" {
 value = aws_instance.sonarqube_server.public_ip
}
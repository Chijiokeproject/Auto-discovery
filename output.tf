output "sonarqube_public_ip" {
  value = module.sonarqube.sonarqube_public_ip
}
output "bastion-public-ip" {
  value = module.bastion.bastion_public_ip
}
output "nexus-public-ip" {
  value = module.nexus.nexus_ip
}
output "nexus-private-ip" {
  value = module.nexus.nexus_private_ip
}
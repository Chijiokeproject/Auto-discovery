output "sonarqube_public_ip" {
  value = module.sonarqube.sonarqube_public_ip
}
output "bastion-public-ip" {
  value = module.bastion.bastion_public_ip
}
output "nexus_ip" {
  value = module.nexus.nexus_ip
}
output "nexus_public_ip" {
  value = module.nexus.nexus_public_ip
}

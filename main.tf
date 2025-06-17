locals {
  name = "auto-discovery"
}

module "vpc" {
  source = "./module/vpc"
  name   = local.name
  az1    = "eu-west-3a"
  az2    = "eu-west-3b"
}
provider "aws" {
  alias  = "paris"
  region = "eu-west-3"
}
data "aws_acm_certificate" "auto_acm_cert" {
  domain              = "chijiokedevops.space"
  statuses            = ["ISSUED"]
  most_recent         = true
  types               = ["AMAZON_ISSUED"]
  key_types           = ["RSA_2048"]
}

data "aws_route53_zone" "auto-discovery-zone" {
  name         = "chijiokedevops.space"
  private_zone = false
}

module "sonarqube" {
  source              = "./module/sonarqube"
  keypair             = module.vpc.public_key
  name                = local.name
  subnet_id           = module.vpc.pub_sub1_id
  bastion_sg          = module.bastion.bastion_sg
  vpc_id              = module.vpc.vpc_id
  domain              = var.domain
  public_subnets      = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
  nr-key              = var.nr-key
  nr-id               = var.nr-id
  route53_zone_id     = data.aws_route53_zone.auto-discovery-zone.zone_id
  acm_certificate_arn = data.aws_acm_certificate.auto_acm_cert.arn
}

module "bastion" {
  source     = "./module/bastion"
  name       = local.name
  keypair    = module.vpc.public_key
  privatekey = module.vpc.private_key
  vpc        = module.vpc.vpc_id
  subnets    = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
}

module "nexus" {
  source              = "./module/nexus"
  name                = local.name
  keypair             = module.vpc.public_key
  #keypair                 = var.keypair
  vpc                 = module.vpc.vpc_id
  subnet1_id          = module.vpc.pub_sub1_id
  subnet2_id          = module.vpc.pub_sub2_id
  bastion_sg          = module.bastion.bastion_sg
  nr-key              = var.nr-key
  nr-id               = var.nr-id
  domain              = var.domain
  subnet              = module.vpc.pub_sub1_id
  acm_certificate_arn = data.aws_acm_certificate.auto_acm_cert.arn
}

module "database" {
  source      = "./module/database"
  name        = local.name
  pri-sub-1   = module.vpc.pri_sub1_id
  pri-sub-2   = module.vpc.pri_sub2_id
  bastion_sg  = module.bastion.bastion_sg
  vpc-id      = module.vpc.vpc_id
  stage-sg    = module.stage-envi.stage-sg
  prod-sg     = module.prod-envi.prod-sg
}

module "ansible" {
  source    = "./module/ansible"
  name      = local.name
  keypair   = module.vpc.public_key
  subnet_id = module.vpc.pri_sub1_id
  vpc       = module.vpc.vpc_id
  bastion_sg   = module.bastion.bastion_sg
  private-key = module.vpc.private_key
  deployment = "./module/ansible/deployment.yml" # Path to the deployment file
  prod-bashscript = "./module/ansible/prod-bashscript.sh" # Path to the prod bash script
  stage-bashscript = "./module/ansible/stage-bashscript.sh" # Path to the stage bash script
  nexus-ip = module.nexus.nexus_ip
  nr-key = var.nr-key
  nr-acc-id = var.nr-id
}

module "prod-envi" {
  source       = "./module/prod-envi"
  name         = local.name
  vpc-id       = module.vpc.vpc_id
  bastion_sg   = module.bastion.bastion_sg
  key-name     = module.vpc.public_key
  pri-subnet1  = module.vpc.pri_sub1_id
  pri-subnet2  = module.vpc.pri_sub2_id
  pub-subnet1  = module.vpc.pub_sub1_id
  pub-subnet2  = module.vpc.pub_sub2_id
  acm-cert-arn = data.aws_acm_certificate.auto_acm_cert.arn
  domain       = var.domain
  nexus-ip     = module.nexus.nexus_ip
  nr-key       = var.nr-key
  nr-acct-id   = var.nr-id  
  ansible      =  module.ansible.ansible_sg
  target_group_arns   = aws_lb_target_group.prod-target-group.arn
}

module "stage-envi" {
  source       = "./module/stage-envi"
  name         = local.name
  vpc-id       = module.vpc.vpc_id
  bastion_sg   = module.bastion.bastion_sg
  key-name     = module.vpc.public_key
  pri-subnet1  = module.vpc.pri_sub1_id
  pri-subnet2  = module.vpc.pri_sub2_id
  pub-subnet1  = module.vpc.pub_sub1_id
  pub-subnet2  = module.vpc.pub_sub2_id
  acm-cert-arn = data.aws_acm_certificate.auto_acm_cert.arn
  domain       = var.domain
  nexus-ip     = module.nexus.nexus_ip
  nr-key       = var.nr-key
  nr-acct-id   = var.nr-id  
  ansible      =  module.ansible.ansible_sg
  target_group_arns  = aws_lb_target_group.stage_target_group.arn
}




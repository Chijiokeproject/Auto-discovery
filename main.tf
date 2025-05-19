locals {
  name = "auto-discovery"
}

module "vpc" {
  source = "./module/vpc"
  name   = local.name
  az1    = "eu-west-2a"
  az2    = "eu-west-2b"
}
provider "aws" {
  alias  = "london"
  region = "eu-west-2"
}
data "aws_acm_certificate" "auto_acm_cert" {
  domain      = "chijiokedevops.space"
  statuses    = ["ISSUED"]
  most_recent = true
}
data "aws_route53_zone" "zone_id" {
  name         = var.domain
  private_zone = false
}

module "sonarqube" {
  source              = "./module/sonarqube"
  key                 = module.vpc.public_key
  name                = local.name
  subnet_id           = module.vpc.pub_sub1_id
  bastion_sg          = module.bastion.bastion_sg
  vpc_id              = module.vpc.vpc_id
  domain              = var.domain
  public_subnets      = [module.vpc.pub_sub1_id, module.vpc.pub_sub2_id]
  nr-key              = var.nr-key
  nr-id               = var.nr-id
  route53_zone_id     = data.aws_route53_zone.zone_id.zone_id
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



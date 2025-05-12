locals {
  name = "auto-discovery"
}

module "vpc" {
  source = "./module/vpc"
  name   = local.name
  az1    = "eu-west-2a"
  az2    = "eu-west-2b"
}

data "aws_acm_certificate" "auto-acm-cert" {
  domain   = "chijiokedevops.space"
  statuses = ["ISSUED"]
}

locals {
  name = "auto-discovery"
}

module "vpc" {
  source = "./module/vpc"
  name   = local.name
  az1    = "eu-west-2a"
  az2    = "eu-west-2b"
}
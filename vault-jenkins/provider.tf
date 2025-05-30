provider "aws" {
  region  = "eu-west-3"
  profile = "auto-discovery"
}

terraform {
  backend "s3" {
    bucket       = "chijioke-bucket-auto-discovery-1"
    key          = "vault-jenkins/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    profile      = "auto-discovery"
    use_lockfile = true
  }
}
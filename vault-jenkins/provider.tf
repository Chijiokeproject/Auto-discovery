provider "aws" {
  region  = "eu-west-2"
  profile = "auto-discovery"
}

terraform {
  backend "s3" {
    bucket       = "chijioke-bucket-auto-discovery"
    key          = "vault-jenkins/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    profile      = "auto-discovery"
    use_lockfile = true
  }
}
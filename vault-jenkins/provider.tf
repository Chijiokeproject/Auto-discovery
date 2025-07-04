provider "aws" {
  region  = "us-west-1"
  profile = "auto-discovery"
}

terraform {
  backend "s3" {
    bucket       = "chijioke-bucket-auto-discovery"
    key          = "vault-jenkins/terraform.tfstate"
    region       = "us-west-1"
    encrypt      = true
    profile      = "auto-discovery"
    use_lockfile = true
  }
}
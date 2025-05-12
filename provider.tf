provider "aws" {
  region  = "eu-west-2"
  profile = "auto-discovery"
}

provider "vault" {
address = "https://vault.chijiokedevops.space"
token   = ""
}

#terraform backend configuration for s3
terraform {
  backend "s3" {
    bucket       = "chijioke-bucket-auto-discovery"
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    profile      = "auto-discovery"
  }
}

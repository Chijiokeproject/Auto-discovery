provider "aws" {
  region  = "eu-west-3"
}

provider "vault" {
  address = "https://vault.chijiokedevops.space"
  token   = "s.gYhlhXu676WRQxv0CsrsE4lM"
}

terraform {
  backend "s3" {
    bucket       = "chijioke-bucket-auto-discovery-1"
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-3"
    use_lockfile = true
  }
}

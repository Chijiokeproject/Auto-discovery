provider "aws" {
  region  = "eu-west-2"
}

provider "vault" {
  address = "https://vault.chijiokedevops.space"
  token   = "s.FSUW6TtH3xrXfYGx6u1bQlrS"
}

terraform {
  backend "s3" {
    bucket       = "chijioke-bucket-auto-discovery"
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}

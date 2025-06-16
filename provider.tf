provider "aws" {
  region  = "eu-west-3"
}

provider "vault" {
  address = "https://vault.chijiokedevops.space"
  token   = "s.d5QDuSm1GZ4y2fcgovjkZov7"
}

terraform {
  backend "s3" {
    bucket       = "chijioke-bucket-auto-discovery-1"
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-3"
    use_lockfile = true
  }
}

provider "aws" {
  region  = "eu-west-2"
}

provider "vault" {
  address = "https://vault.chijiokedevops.space"
  token   = "s.siPNTd1Uya8vS0l9PJ8n6Adx"
}

terraform {
  backend "s3" {
    bucket       = "chijioke-bucket-auto-discovery"
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}

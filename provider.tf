provider "aws" {
  region  = "us-west-1"
}

provider "vault" {
  address = "https://vault.chijiokedevops.space"
  token   = "s.A2jZbe5LYNaQSpVhW3wRuwvi"
}
#terraform {
 # backend "s3" {
  #  bucket       = "chijioke-bucket-auto-discovery"
   # key          = "infrastructure/terraform.tfstate"
   # region       = "us-west-1"
   # use_lockfile = true
  #}
#}

terraform {
  backend "s3" {
    bucket = "chijioke-bucket-auto-discovery"
    key    = "env:/terraform.tfstate"
    region = "us-west-1"
  }
}




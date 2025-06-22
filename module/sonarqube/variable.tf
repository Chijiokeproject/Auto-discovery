variable "keypair" {}
variable "name" {}
variable "subnet_id" {}
variable "bastion_sg" {}
variable "vpc" {}
variable "domain" {
  default = "chijiokedevops.space"
}
variable "subnet1_id" {}
variable "subnet2_id" {}
variable "acm_certificate_arn" {}
variable "nr_key" {}
variable "nr_acct_id" {}


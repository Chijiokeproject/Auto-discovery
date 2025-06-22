variable "keypair" {}
variable "name" {}
variable "subnet_id" {}
variable "bastion_sg" {}
variable "vpc_id" {}
variable "domain" {
  default = "chijiokedevops.space"
}
variable "public_subnets" {}
variable "auto_acm_cert" {
  description = "ARN of the ACM certificate"
  type        = string
}
variable "route53_zone_id" {}
variable "nr_key" {}
variable "nr_acct_id" {}


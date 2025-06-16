variable "keypair" {}
variable "name" {}
variable "subnet_id" {}
variable "bastion_sg" {}
variable "vpc_id" {}
variable "domain" {
  default = "chijiokedevops.space"
}
variable "public_subnets" {}
variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate to attach to the ELB"
  type        = string
}
variable "route53_zone_id" {}
variable "nr-key" {}
variable "nr-id" {}

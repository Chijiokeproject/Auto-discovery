variable "name" {}
variable "vpc-id" {}
variable "bastion_sg" {}
variable "key-name" {}
variable "pri_subnet1" {}
variable "pri_subnet2" {}
variable "pub_subnet1" {}
variable "pub_subnet2" {}
variable "domain" {}
variable "nexus-ip" {}
variable "nr-key" {}
variable "nr-acct-id" {}
variable "ansible" {}
variable "acm-cert-arn" {
  type        = string
  description = "ARN of the SSL certificate for HTTPS listener"
}


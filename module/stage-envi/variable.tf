variable "name" {}
variable "vpc-id" {}
variable "bastion_sg" {}
variable "key-name" {}
variable "pri-subnet1" {}
variable "pri-subnet2" {}
variable "pub-subnet1" {}
variable "pub-subnet2" {}
variable "domain" {}
variable "nexus-ip" {}
variable "nr-key" {}
variable "nr-acct-id" {}
variable "ansible" {}
variable "target_group_arn" {
  type = string
}

variable "acm-cert-arn" {
  type        = string
  description = "ARN of the SSL certificate for HTTPS listener"
}
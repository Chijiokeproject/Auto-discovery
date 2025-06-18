variable "name" {}
variable "vpc-id" {}
variable "bastion_sg" {}
variable "key-name" {}
variable "pri-subnet1" {}
variable "pri_subnet2" {}
variable "pub_subnet1" {}
variable "pub_subnet2" {}
variable "domain" {}
variable "nexus-ip" {}
variable "nr_key" {}
variable "nr_acct_id" {}
variable "ansible" {}
variable "target_group_arn" {
  description = "Target group ARN for the load balancer"
  type        = string
}
variable "acm-cert-arn" {
  type        = string
  description = "ARN of the SSL certificate for HTTPS listener"
}
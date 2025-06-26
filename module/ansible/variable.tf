variable "keypair" {}
variable "name" {}
variable "subnet_id" {}
variable "vpc" {}
variable "bastion_key" {}
variable "private_key" {}
variable "nexus_ip" {}
variable "nr_key" {}
variable "nr_acct_id" {}
variable "s3Bucket" {
  description = "The name of the S3 bucket to be used by the Ansible module"
  type        = string
}


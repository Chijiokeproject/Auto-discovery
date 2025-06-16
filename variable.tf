variable "domain" {
  description = "The domain name for the project"
  type        = string
  default     = "chijiokedevops.space"
}
variable "nr-key" {
  default = ""
}
variable "nr-id" {
  default = 6360298
}

variable "keypair" {
  description = "SSH Key Pair name used for Nexus and other EC2s"
  type        = string
}

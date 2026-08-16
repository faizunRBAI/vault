variable "project_name" {
  description = "Project name used as a prefix for all resource names and tags."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the Vault server."
  type        = string
  default     = "t3.small"
}

variable "ssh_public_key" {
  description = "RSA public key material to register as the EC2 key pair."
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "Operator source IP in CIDR notation (e.g. 1.2.3.4/32). Inbound :22 and :8200 are restricted to this address."
  type        = string
}

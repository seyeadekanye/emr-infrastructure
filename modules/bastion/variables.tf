variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type        = string
  description = "Single public subnet to place the bastion in"
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH (e.g. [\"1.2.3.4/32\"] for your IP)"
}

variable "key_name" {
  type        = string
  default     = ""
  description = "EC2 key pair name for SSH access (leave empty to use Session Manager only)"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

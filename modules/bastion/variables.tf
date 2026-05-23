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

variable "rds_sg_id" {
  type        = string
  description = "RDS security group ID — bastion will be granted ingress on 3306"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

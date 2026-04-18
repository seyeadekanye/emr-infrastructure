variable "env" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "replica_regions" {
  type        = list(string)
  default     = []
  description = "Regions to replicate secrets to (e.g. [\"us-west-2\"])"
}

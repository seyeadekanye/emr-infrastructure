variable "domain_name" {
  type        = string
  description = "Domain to look up or provision a cert for"
}

variable "use_existing_cert" {
  type    = bool
  default = true
}

variable "existing_cert_arn" {
  type        = string
  default     = ""
  description = "Use this ARN directly instead of a data source lookup"
}

variable "env" {
  type = string
}

variable "domain" {
  type        = string
  description = "Domain to verify with SES (e.g. docli.io)"
}

variable "create_route53_records" {
  type        = bool
  default     = false
  description = "Set true in prod where Route53 is authoritative — auto-creates DKIM and verification records"
}

variable "route53_zone_id" {
  type        = string
  default     = ""
  description = "Required when create_route53_records = true"
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "certificate_arn" {
  type = string
}

variable "api_domain_name" {
  type = string
}

variable "failover_domain_name" {
  type        = string
  default     = ""
  description = "Optional user-facing domain (e.g. api.mallow.io) that CNAMEs via Route53 failover to the regional API domain"
}

variable "failover_certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN covering the failover domain (required if failover_domain_name is set)"
}

variable "cors_allow_origin" {
  type        = string
  default     = "*"
  description = "Origin for CORS Access-Control-Allow-Origin header (e.g. https://mallow.io)"
}

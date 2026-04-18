variable "root_domain" {
  type        = string
  description = "Apex domain — becomes the Route53 hosted zone (e.g. docli.io)"
}

variable "api_target" {
  type        = string
  description = "API GW regional domain name (custom_domain_target output)"
}

variable "cloudfront_domain" {
  type        = string
  description = "CloudFront distribution domain name"
}

variable "frontend_domain" {
  type        = string
  description = "FQDN for the frontend (apex or subdomain)"
}

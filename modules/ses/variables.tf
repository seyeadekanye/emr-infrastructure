variable "env" {
  type = string
}

variable "domain" {
  type        = string
  description = "Domain to verify with SES (e.g. mallow.io)"
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

variable "webhook_subscription_url" {
  type        = string
  default     = ""
  description = "HTTPS URL to subscribe to the SES notifications SNS topic for bounce/complaint events. Typically https://<api_domain>/api/v1/messaging/webhooks/ses. Empty disables the subscription."
}

variable "env" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type = string
}

variable "single_nat_gateway" {
  type = bool
}

variable "rds_instance_class" {
  type = string
}

variable "rds_allocated_storage" {
  type = number
}

variable "rds_multi_az" {
  type = bool
}

variable "rds_deletion_protection" {
  type = bool
}

variable "ecs_desired_count" {
  type = number
}

variable "ecs_cpu" {
  type = number
}

variable "ecs_memory" {
  type = number
}

variable "log_retention_days" {
  type = number
}

variable "cloudfront_price_class" {
  type = string
}

variable "api_domain_name" {
  type = string
}

variable "frontend_domain" {
  type = string
}

variable "use_existing_cert" {
  type    = bool
  default = true
}

variable "existing_cert_arn" {
  type        = string
  default     = ""
  description = "ACM cert ARN for API Gateway in us-east-2 (leave empty to look up by domain)"
}

variable "cloudfront_cert_arn" {
  type        = string
  default     = ""
  description = "ACM cert ARN for CloudFront in us-east-1 (leave empty to look up by domain)"
}

variable "ses_domain" {
  type        = string
  description = "Domain to register with SES for sending email (e.g. dev.docli.io)"
}

# ── Direct DB access (dev only) ────────────────────────────────────────────────

variable "db_allowed_cidrs" {
  type        = list(string)
  description = "Your IP in CIDR notation for direct RDS access (e.g. [\"1.2.3.4/32\"])"
}

# Passed via -var in CI — never committed to tfvars
variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "env" {
  type    = string
  default = "prod"
}

variable "root_domain" {
  type        = string
  description = "Apex domain for Route53 hosted zone (e.g. docli.io)"
}

# ── Regions ───────────────────────────────────────────────────────────────────

variable "secondary_region" {
  type    = string
  default = "us-west-2"
}

# ── Primary networking ────────────────────────────────────────────────────────

variable "vpc_cidr" {
  type = string
}

variable "single_nat_gateway" {
  type = bool
}

# ── Secondary networking ──────────────────────────────────────────────────────

variable "secondary_vpc_cidr" {
  type = string
}

# ── RDS ───────────────────────────────────────────────────────────────────────

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

# ── ECS ───────────────────────────────────────────────────────────────────────

variable "ecs_desired_count" {
  type = number
}

variable "secondary_ecs_desired_count" {
  type        = number
  description = "Warm standby — scale to ecs_desired_count during failover"
  default     = 1
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

# ── Frontend ──────────────────────────────────────────────────────────────────

variable "cloudfront_price_class" {
  type = string
}

variable "frontend_domain" {
  type = string
}

# ── ACM ───────────────────────────────────────────────────────────────────────

variable "primary_api_domain_name" {
  type        = string
  description = "Regional API GW custom domain in us-east-2 (e.g. api-us-east-2.docli.io)"
}

variable "secondary_api_domain_name" {
  type        = string
  description = "Regional API GW custom domain in secondary region (e.g. api-us-west-2.docli.io)"
}

variable "use_existing_cert" {
  type    = bool
  default = true
}

variable "primary_existing_cert_arn" {
  type    = string
  default = ""
}

variable "secondary_existing_cert_arn" {
  type    = string
  default = ""
}

variable "cloudfront_cert_arn" {
  type        = string
  default     = ""
  description = "ACM cert ARN in us-east-1 for CloudFront"
}

# ── Secrets — passed via -var in CI, never committed ─────────────────────────

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

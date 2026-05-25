variable "env" {
  type = string
}

variable "ecr_image_url" {
  type        = string
  description = "Full ECR image URL, e.g. <acct>.dkr.ecr.<region>.amazonaws.com/emr-worker:latest"
}

variable "cluster_id" {
  type        = string
  description = "ARN of the shared ECS cluster (typically module.ecs.cluster_arn)"
}

variable "db_secret_arn" {
  type = string
}

variable "db_username" {
  type        = string
  description = "Master DB username for control-plane + tenant DBs. Injected as CONTROL_PLANE_DB_USERNAME + DEFAULT_TENANT_DB_USERNAME so the worker doesn't resolve the wrong default from elsewhere on the classpath."
  default     = "emradmin"
}

variable "jwt_secret_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_sg_id" {
  type        = string
  description = "Security group id for the worker tasks. Reusing the API's SG is acceptable for dev; tighten in prod."
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "ses_identity_arns" {
  type    = list(string)
  default = []
}

variable "s3_bucket_arns" {
  type    = list(string)
  default = []
}

variable "document_s3_bucket" {
  type    = string
  default = ""
}

variable "enable_bedrock" {
  type    = bool
  default = false
}

variable "kms_key_arns" {
  type    = list(string)
  default = []
}

# ── Messaging knobs (mirror modules/ecs) ─────────────────────────────────────

variable "messaging_email_enabled" {
  type    = bool
  default = false
}

variable "messaging_email_from" {
  type    = string
  default = ""
}

variable "messaging_ses_config_set" {
  type    = string
  default = ""
}

variable "messaging_sms_enabled" {
  type    = bool
  default = false
}

variable "messaging_sms_provider" {
  type    = string
  default = "sns"
}

variable "messaging_billing_notify_email" {
  type    = string
  default = ""
}

variable "messaging_grant_sns_publish" {
  type    = bool
  default = false
}

# ── Worker-only @Scheduled kill switches ─────────────────────────────────────
# Default false in this module so first-time deploys verify the JVM boots
# before firing every scheduled bean across every tenant. Environments
# explicitly opt in once a clean boot is observed.

variable "messaging_outbox_enabled" {
  type        = bool
  default     = false
  description = "Master switch for MessageOutboxWorker.drain (15s cadence). Start false on first deploy."
}

variable "messaging_reminders_enabled" {
  type    = bool
  default = false
}

variable "messaging_auth_expiry_enabled" {
  type    = bool
  default = false
}

variable "messaging_tenant_onboarding_enabled" {
  type    = bool
  default = false
}

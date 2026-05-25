variable "env" {
  type = string
}

variable "ecr_image_url" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "jwt_secret_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "desired_count" {
  type = number
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "log_retention_days" {
  type = number
}

variable "ses_identity_arns" {
  type        = list(string)
  default     = []
  description = "SES domain identity ARNs the task role may send from"
}

variable "s3_bucket_arns" {
  type        = list(string)
  default     = []
  description = "S3 bucket ARNs the task role can read/write (tenant document storage)"
}

variable "enable_bedrock" {
  type        = bool
  default     = false
  description = "Grant the task role permissions to invoke Bedrock models"
}

variable "document_s3_bucket" {
  type        = string
  default     = ""
  description = "S3 bucket name for tenant document storage"
}

variable "enable_agreements_s3" {
  type        = bool
  default     = false
  description = "Enable IAM permissions for the agreements S3 bucket"
}

variable "agreement_s3_bucket_arn" {
  type        = string
  default     = ""
  description = "ARN of the agreements S3 bucket (Object Lock enabled)"
}

variable "agreement_s3_bucket_name" {
  type        = string
  default     = ""
  description = "Name of the agreements S3 bucket"
}

variable "kms_key_arns" {
  type        = list(string)
  default     = []
  description = "KMS key ARNs the task execution role needs kms:Decrypt on (for secrets encrypted with CMKs)"
}

# ── Messaging platform (Slice 1a — 6c go-live) ───────────────────────────────
# All optional. Defaults preserve the local/log-only behavior of the messaging
# stack until the operator explicitly turns it on per environment.

variable "messaging_email_enabled" {
  type        = bool
  default     = false
  description = "Set true to activate SesEmailProvider. Requires a verified SES identity and SES out-of-sandbox status."
}

variable "messaging_email_from" {
  type        = string
  default     = ""
  description = "Verified SES sender address. Required when messaging_email_enabled=true."
}

variable "messaging_ses_config_set" {
  type        = string
  default     = ""
  description = "SES configuration-set name used for bounce/complaint event publishing. Typically the output of module.ses.configuration_set_name."
}

variable "messaging_sms_enabled" {
  type        = bool
  default     = false
  description = "Set true to activate the SMS provider. Off by default — SNS direct-publish has no opt-out introspection (DESIGN.md §B); End User Messaging SMS gated on 10DLC registration."
}

variable "messaging_sms_provider" {
  type        = string
  default     = "sns"
  description = "Selects the SMS provider bean: sns | endusermessaging. The latter is a placeholder until the provider implementation lands."
}

variable "messaging_billing_notify_email" {
  type        = string
  default     = ""
  description = "Billing-team inbox for ClaimDenied / PaymentReceived / AuthExpiry listener sends."
}

variable "messaging_compliance_notify_email" {
  type        = string
  default     = ""
  description = "Compliance officer inbox for IncidentFiled listener sends."
}

variable "messaging_mallowhq_billing_email" {
  type        = string
  default     = ""
  description = "MallowHQ ops inbox preferred over the tenant contact for Stripe PAYMENT_FAILED."
}

variable "messaging_grant_sns_publish" {
  type        = bool
  default     = false
  description = "Grant the task role sns:Publish (required when messaging_sms_enabled=true and provider=sns)."
}

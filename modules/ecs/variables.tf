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

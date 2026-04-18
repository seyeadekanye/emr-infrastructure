variable "env" {
  type = string
}

variable "cors_origins" {
  type        = list(string)
  default     = []
  description = "Allowed origins for S3 CORS (e.g. [\"https://docli.io\"])"
}

variable "enable_replication" {
  type    = bool
  default = false
}

variable "replication_bucket_arn" {
  type        = string
  default     = ""
  description = "Destination bucket ARN for cross-region replication"
}

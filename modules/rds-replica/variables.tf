variable "env" {
  type        = string
  description = "Include region suffix to avoid IAM/name conflicts (e.g. prod-us-west-2)"
}

variable "source_db_arn" {
  type        = string
  description = "ARN of the primary RDS instance to replicate from"
}

variable "db_subnet_ids" {
  type = list(string)
}

variable "rds_sg_id" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "KMS key ARN in the replica region for encryption (empty = AWS managed key)"
}

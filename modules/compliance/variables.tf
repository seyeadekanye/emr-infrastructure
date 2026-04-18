variable "account_id" {
  type = string
}

variable "trail_name" {
  type    = string
  default = "emr-cloudtrail"
}

variable "guardduty_notification_email" {
  type        = string
  default     = ""
  description = "Email to subscribe to GuardDuty findings SNS topic (optional — subscribe manually if left empty)"
}

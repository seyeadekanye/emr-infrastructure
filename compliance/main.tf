terraform {
  required_version = ">= 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "emr-terraform-state-736822756246"
    key            = "compliance/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "emr-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

module "compliance" {
  source                       = "../modules/compliance"
  account_id                   = "736822756246"
  guardduty_notification_email = var.guardduty_notification_email
}

variable "guardduty_notification_email" {
  type        = string
  default     = ""
  description = "Email for GuardDuty alerts (optional — can subscribe manually later)"
}

output "cloudtrail_s3_bucket" {
  value = module.compliance.cloudtrail_s3_bucket
}

output "guardduty_detector_id" {
  value = module.compliance.guardduty_detector_id
}

output "guardduty_findings_topic_arn" {
  value = module.compliance.guardduty_findings_topic_arn
}

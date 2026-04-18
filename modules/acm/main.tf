terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Looks up an existing ACM certificate by domain name.
# If existing_cert_arn is provided it is used directly (no data source call).
#
# New cert provisioning stub (uncomment when use_existing_cert = false):
#
# resource "aws_acm_certificate" "new" {
#   domain_name       = var.domain_name
#   validation_method = "DNS"
#   lifecycle { create_before_destroy = true }
# }
#
# resource "aws_acm_certificate_validation" "new" {
#   certificate_arn = aws_acm_certificate.new.arn
#   # Add the validation_record_fqdns after creating DNS CNAME at registrar
# }

data "aws_acm_certificate" "existing" {
  count    = var.use_existing_cert && var.existing_cert_arn == "" ? 1 : 0
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

locals {
  certificate_arn = coalesce(
    var.existing_cert_arn,
    try(data.aws_acm_certificate.existing[0].arn, "")
  )
}

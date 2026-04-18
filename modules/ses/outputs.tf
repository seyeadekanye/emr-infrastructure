output "domain_identity_arn" {
  value       = aws_ses_domain_identity.main.arn
  description = "Passed to ECS task role to scope ses:SendEmail permission"
}

output "configuration_set_name" {
  value = aws_ses_configuration_set.main.name
}

output "ses_notifications_topic_arn" {
  value       = aws_sns_topic.ses_notifications.arn
  description = "Subscribe to this SNS topic to handle bounce and complaint events"
}

# ── Manual DNS records (used in dev where create_route53_records = false) ─────

output "verification_token" {
  value       = aws_ses_domain_identity.main.verification_token
  description = "Add TXT record: _amazonses.{domain} → this value"
}

output "dkim_records" {
  value = [
    for token in aws_ses_domain_dkim.main.dkim_tokens :
    {
      name  = "${token}._domainkey.${var.domain}"
      value = "${token}.dkim.amazonses.com"
    }
  ]
  description = "Add 3 CNAME records at your registrar (dev only)"
}

output "mail_from_mx_record" {
  value       = "10 feedback-smtp.${data.aws_region.current.name}.amazonses.com"
  description = "Add MX record for mail.{domain} → this value (dev only)"
}

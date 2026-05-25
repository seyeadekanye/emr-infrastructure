data "aws_region" "current" {}

# ── Domain Identity ───────────────────────────────────────────────────────────

resource "aws_ses_domain_identity" "main" {
  domain = var.domain
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "mail.${var.domain}"
}

# ── Configuration Set ─────────────────────────────────────────────────────────

resource "aws_ses_configuration_set" "main" {
  name = "emr-${var.env}-ses"

  delivery_options {
    tls_policy = "Require"
  }
}

# ── Bounce / Complaint Notifications ─────────────────────────────────────────

resource "aws_sns_topic" "ses_notifications" {
  name = "emr-${var.env}-ses-notifications"
}

resource "aws_ses_identity_notification_topic" "bounce" {
  identity                 = aws_ses_domain_identity.main.domain
  notification_type        = "Bounce"
  topic_arn                = aws_sns_topic.ses_notifications.arn
  include_original_headers = false
}

resource "aws_ses_identity_notification_topic" "complaint" {
  identity                 = aws_ses_domain_identity.main.domain
  notification_type        = "Complaint"
  topic_arn                = aws_sns_topic.ses_notifications.arn
  include_original_headers = false
}

# ── HTTPS subscription delivering bounce/complaint events to the application ──
# When set, AWS POSTs a SubscriptionConfirmation to the endpoint; emr-api's
# MessageWebhookController.confirmSubscription handler GETs the included
# SubscribeURL automatically. endpoint_auto_confirms tells Terraform to poll
# AWS until the subscription state flips to "Confirmed" before the apply
# returns — so a misconfigured backend surfaces as an apply timeout instead
# of silently breaking later inbound events.
resource "aws_sns_topic_subscription" "ses_webhook" {
  count                  = var.webhook_subscription_url != "" ? 1 : 0
  topic_arn              = aws_sns_topic.ses_notifications.arn
  protocol               = "https"
  endpoint               = var.webhook_subscription_url
  endpoint_auto_confirms = true
}

# ── Route53 Records (prod only) ───────────────────────────────────────────────
# In dev, DNS is external — use the outputs below to add records manually at
# your registrar. Verification can take up to 72 hours.

resource "aws_route53_record" "ses_verification" {
  count   = var.create_route53_records ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.domain}"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.main.verification_token]
}

resource "aws_route53_record" "dkim" {
  count   = var.create_route53_records ? 3 : 0
  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey.${var.domain}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "mail_from_mx" {
  count   = var.create_route53_records ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "mail.${var.domain}"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.${data.aws_region.current.name}.amazonses.com"]
}

resource "aws_route53_record" "mail_from_spf" {
  count   = var.create_route53_records ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "mail.${var.domain}"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

# Waits for domain verification to complete after DNS records are created.
# Only runs in prod where records are auto-created above.
# Temporarily commented out — SES verification still propagating.
# Uncomment and re-apply once `aws ses get-identity-verification-attributes --identities "mallow.io" --region us-east-1` shows "Success".
# resource "aws_ses_domain_identity_verification" "main" {
#   count      = var.create_route53_records ? 1 : 0
#   domain     = aws_ses_domain_identity.main.domain
#   depends_on = [aws_route53_record.ses_verification, aws_route53_record.dkim]
#
#   timeouts {
#     create = "30m"
#   }
# }

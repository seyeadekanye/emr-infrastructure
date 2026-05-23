# ── Hosted Zone ───────────────────────────────────────────────────────────────
# Registrar must delegate to the NS records output from this module.

resource "aws_route53_zone" "main" {
  name = var.root_domain
}

# ── API Record ───────────────────────────────────────────────────────────────
# Simple CNAME pointing api.mallow.io directly at the primary API GW.
# When multi-region failover is re-enabled, replace with failover routing.

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.root_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [var.api_target]
}

# ── Frontend Record ───────────────────────────────────────────────────────────
# ALIAS A record supports both apex and subdomains; CloudFront hosted zone ID is constant.

resource "aws_route53_record" "frontend" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.frontend_domain
  type    = "A"

  alias {
    name                   = var.cloudfront_domain
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront global hosted zone ID
    evaluate_target_health = false
  }
}

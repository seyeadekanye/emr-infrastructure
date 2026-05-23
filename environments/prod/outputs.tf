# ── Route53 ───────────────────────────────────────────────────────────────────

output "route53_name_servers" {
  value       = module.route53.name_servers
  description = "Delegate these NS records at your registrar for mallow.io"
}

output "api_fqdn" {
  value       = module.route53.api_fqdn
  description = "User-facing API endpoint — set VITE_JAVA_API_URL to this"
}

# ── Primary ───────────────────────────────────────────────────────────────────

output "primary_api_custom_domain" {
  value = module.api_gateway.api_custom_domain
}

output "primary_custom_domain_target" {
  value       = module.api_gateway.custom_domain_target
  description = "Route53 CNAME target for primary region"
}

output "cloudfront_domain" {
  value       = module.frontend.cloudfront_domain
  description = "CloudFront distribution domain (Route53 ALIAS record points here)"
}

output "primary_db_endpoint" {
  value = module.rds.db_endpoint
}

output "primary_ecs_cluster_arn" {
  value = module.ecs.cluster_arn
}

output "ecr_repo_url" {
  value = module.ecr.repo_urls["emr-api"]
}

output "documents_bucket_name" {
  value = module.storage.bucket_name
}

output "bastion_instance_id" {
  value       = module.bastion.instance_id
  description = "Use: aws ssm start-session --target <this_value>"
}

output "documents_bucket_secondary" {
  value       = module.storage_secondary.bucket_name
  description = "S3 replication target in us-west-2"
}

output "s3_bucket_name" {
  value = module.frontend.s3_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.frontend.distribution_id
}

# ── SES ───────────────────────────────────────────────────────────────────────

output "ses_notifications_topic_arn" {
  value       = module.ses.ses_notifications_topic_arn
  description = "Subscribe to handle bounce and complaint events"
}

output "ses_configuration_set_name" {
  value = module.ses.configuration_set_name
}

output "ses_verification_token" {
  value       = module.ses.verification_token
  description = "Add TXT record in GoDaddy: _amazonses.mallowhealth.com → this value"
}

output "ses_dkim_records" {
  value       = module.ses.dkim_records
  description = "Add these 3 CNAME records in GoDaddy"
}

output "ses_mail_from_mx" {
  value       = module.ses.mail_from_mx_record
  description = "Add MX record in GoDaddy: mail.mallowhealth.com → this value (priority 10)"
}

# ── Monitoring ────────────────────────────────────────────────────────────────

output "monitoring_critical_topic_arn" {
  value       = module.monitoring.critical_topic_arn
  description = "Subscribe additional endpoints (Slack, PagerDuty) for critical alerts"
}

output "monitoring_warning_topic_arn" {
  value       = module.monitoring.warning_topic_arn
  description = "Subscribe additional endpoints for warning alerts"
}

output "monitoring_dashboard_name" {
  value       = module.monitoring.dashboard_name
  description = "CloudWatch dashboard: emr-prod-overview"
}

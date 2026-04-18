output "api_custom_domain" {
  value = module.api_gateway.api_custom_domain
}

output "custom_domain_target" {
  value       = module.api_gateway.custom_domain_target
  description = "Add CNAME at registrar: api_domain_name → this value"
}

output "cloudfront_domain" {
  value       = module.frontend.cloudfront_domain
  description = "Add CNAME at registrar: frontend_domain → this value"
}

output "s3_bucket_name" {
  value = module.frontend.s3_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.frontend.distribution_id
}

output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "ecs_cluster_arn" {
  value = module.ecs.cluster_arn
}

output "ecr_repo_url" {
  value = module.ecr.repo_urls["emr-api"]
}

output "documents_bucket_name" {
  value = module.storage.bucket_name
}

# ── SES — add these records manually at your registrar ────────────────────────

output "ses_verification_token" {
  value       = module.ses.verification_token
  description = "Add TXT record: _amazonses.<ses_domain> → this value"
}

output "ses_dkim_records" {
  value       = module.ses.dkim_records
  description = "Add these 3 CNAME records at your registrar"
}

output "ses_mail_from_mx" {
  value       = module.ses.mail_from_mx_record
  description = "Add MX record: mail.<ses_domain> → this value (priority 10)"
}

output "ses_notifications_topic_arn" {
  value = module.ses.ses_notifications_topic_arn
}

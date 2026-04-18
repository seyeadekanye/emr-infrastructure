output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.frontend.domain_name
  description = "Add as CNAME at registrar: domain_name → this value"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "distribution_id" {
  value       = aws_cloudfront_distribution.frontend.id
  description = "Used for cache invalidation in deploy pipeline"
}

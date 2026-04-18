output "cloudtrail_arn" {
  value = aws_cloudtrail.main.arn
}

output "cloudtrail_s3_bucket" {
  value = aws_s3_bucket.cloudtrail.bucket
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}

output "guardduty_findings_topic_arn" {
  value       = aws_sns_topic.guardduty_findings.arn
  description = "Subscribe to receive GuardDuty findings (MEDIUM severity and above)"
}

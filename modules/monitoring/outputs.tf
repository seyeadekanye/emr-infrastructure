output "critical_topic_arn" {
  value       = aws_sns_topic.critical.arn
  description = "SNS topic ARN for critical alerts — subscribe additional endpoints here"
}

output "warning_topic_arn" {
  value       = aws_sns_topic.warning.arn
  description = "SNS topic ARN for warning alerts — subscribe additional endpoints here"
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}

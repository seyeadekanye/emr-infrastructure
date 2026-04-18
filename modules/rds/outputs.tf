output "db_endpoint" {
  value = aws_db_instance.main.address
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_arn" {
  value       = aws_db_instance.main.arn
  description = "Used as source_db_arn for cross-region read replica"
}

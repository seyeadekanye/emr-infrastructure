output "db_endpoint" {
  value = aws_db_instance.replica.address
}

output "db_arn" {
  value = aws_db_instance.replica.arn
}

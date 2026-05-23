output "instance_id" {
  value       = aws_instance.bastion.id
  description = "Use with: aws ssm start-session --target <instance_id>"
}

output "security_group_id" {
  value = aws_security_group.bastion.id
}

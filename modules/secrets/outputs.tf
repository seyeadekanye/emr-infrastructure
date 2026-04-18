output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt.arn
}

output "kms_key_arn" {
  value = aws_kms_key.secrets.arn
}

# Map of region → replica ARN — use these for ECS tasks in secondary regions.
# Replica ARNs share the same name but in a different region.
output "replica_db_secret_arns" {
  value = {
    for r in var.replica_regions :
    r => replace(aws_secretsmanager_secret.db.arn, data.aws_region.current.name, r)
  }
}

output "replica_jwt_secret_arns" {
  value = {
    for r in var.replica_regions :
    r => replace(aws_secretsmanager_secret.jwt.arn, data.aws_region.current.name, r)
  }
}

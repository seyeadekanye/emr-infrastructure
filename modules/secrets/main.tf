data "aws_region" "current" {}

resource "aws_kms_key" "secrets" {
  description             = "emr-${var.env}-secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "emr-${var.env}-secrets" }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/emr-${var.env}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "db" {
  name       = "emr/${var.env}/db"
  kms_key_id = aws_kms_key.secrets.arn
  tags       = { Name = "emr-${var.env}-db-secret" }

  dynamic "replica" {
    for_each = var.replica_regions
    content {
      region = replica.value
    }
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({ password = var.db_password })
}

resource "aws_secretsmanager_secret" "jwt" {
  name       = "emr/${var.env}/jwt"
  kms_key_id = aws_kms_key.secrets.arn
  tags       = { Name = "emr-${var.env}-jwt-secret" }

  dynamic "replica" {
    for_each = var.replica_regions
    content {
      region = replica.value
    }
  }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({ secret = var.jwt_secret })
}

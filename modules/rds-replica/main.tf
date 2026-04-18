terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Cross-region read replica of the primary MariaDB instance.
#
# Failover procedure (manual):
#   1. aws rds promote-read-replica --db-instance-identifier emr-{env}-db-replica
#   2. Update ECS task definition DB_HOST to point at replica endpoint
#   3. Route53 failover record handles API traffic automatically once ECS is healthy
#
# Note: Terraform does not manage the promotion. After promotion, the replica
# becomes a standalone instance and must be imported or re-created as an
# aws_db_instance if you want Terraform to manage it going forward.

resource "aws_db_subnet_group" "replica" {
  name       = "emr-${var.env}-replica-subnet-group"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "emr-${var.env}-replica-subnet-group" }
}

resource "aws_db_instance" "replica" {
  identifier          = "emr-${var.env}-db-replica"
  replicate_source_db = var.source_db_arn
  instance_class      = var.instance_class

  db_subnet_group_name   = aws_db_subnet_group.replica.name
  vpc_security_group_ids = [var.rds_sg_id]

  storage_encrypted   = true
  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately   = true

  tags = { Name = "emr-${var.env}-db-replica" }
}

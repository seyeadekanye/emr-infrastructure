resource "aws_db_subnet_group" "main" {
  name       = "emr-${var.env}-db-subnet-group"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "emr-${var.env}-db-subnet-group" }
}

resource "aws_db_parameter_group" "main" {
  name   = "emr-${var.env}-db-params"
  family = "mariadb10.11"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }
  parameter {
    name         = "log_bin_trust_function_creators"
    value        = "1"
    apply_method = "immediate"
  }
}

resource "aws_db_instance" "main" {
  identifier        = "emr-${var.env}-db"
  engine            = "mariadb"
  engine_version    = "10.11"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  db_name           = "emr"
  username          = "emradmin"
  password          = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  publicly_accessible     = var.publicly_accessible
  multi_az                = var.multi_az
  storage_encrypted       = true
  backup_retention_period = 7
  maintenance_window      = "sun:03:00-sun:04:00"
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = !var.deletion_protection

  tags = { Name = "emr-${var.env}-db" }
}

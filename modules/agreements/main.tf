terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

# ── Agreements S3 Bucket (Object Lock enabled) ──────────────────────────────
# Stores draft and executed agreement PDFs (MSA, BAA, Order Forms, Amendments).
# Executed docs use COMPLIANCE-mode Object Lock for 7-year HIPAA retention.

resource "aws_s3_bucket" "agreements" {
  bucket              = "emr-${var.env}-agreements"
  object_lock_enabled = true

  tags = { Name = "emr-${var.env}-agreements" }
}

resource "aws_s3_bucket_versioning" "agreements" {
  bucket = aws_s3_bucket.agreements.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "agreements" {
  bucket = aws_s3_bucket.agreements.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "agreements" {
  bucket = aws_s3_bucket.agreements.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "agreements" {
  bucket = aws_s3_bucket.agreements.id

  rule {
    default_retention {
      mode  = "COMPLIANCE"
      years = 7
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "agreements" {
  bucket = aws_s3_bucket.agreements.id

  rule {
    id     = "expire-drafts"
    status = "Enabled"

    filter {
      prefix = "drafts/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

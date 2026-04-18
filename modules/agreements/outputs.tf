output "bucket_name" {
  value = aws_s3_bucket.agreements.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.agreements.arn
}

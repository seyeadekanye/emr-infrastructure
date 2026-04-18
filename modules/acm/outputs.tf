output "certificate_arn" {
  value = local.certificate_arn
}

# Only populated when provisioning a new cert (stub path)
output "validation_cname" {
  value = null
}

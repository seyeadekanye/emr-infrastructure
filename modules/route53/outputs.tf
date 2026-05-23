output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "name_servers" {
  value       = aws_route53_zone.main.name_servers
  description = "Delegate these NS records at your registrar for mallow.io"
}

output "api_fqdn" {
  value       = "api.${var.root_domain}"
  description = "User-facing API endpoint — set VITE_JAVA_API_URL to this"
}

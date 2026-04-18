output "api_invoke_url" {
  value = aws_api_gateway_stage.main.invoke_url
}

output "api_custom_domain" {
  value = aws_api_gateway_domain_name.main.domain_name
}

output "custom_domain_target" {
  value       = aws_api_gateway_domain_name.main.regional_domain_name
  description = "Add as CNAME at registrar: api_domain_name → this value"
}

output "nlb_dns" {
  value = aws_lb.main.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.api.arn
}

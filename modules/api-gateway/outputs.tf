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

output "rest_api_name" {
  value = aws_api_gateway_rest_api.main.name
}

output "stage_name" {
  value = aws_api_gateway_stage.main.stage_name
}

output "nlb_arn_suffix" {
  value = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.api.arn_suffix
}

variable "env" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for alarm notifications"
}

# ── ECS ───────────────────────────────────────────────────────────────────────

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "ecs_desired_count" {
  type        = number
  description = "Expected running task count — alarm fires if below this"
}

variable "ecs_log_group_name" {
  type        = string
  description = "CloudWatch log group for ECS tasks (e.g. /ecs/emr-prod)"
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "rds_instance_id" {
  type        = string
  description = "RDS DB instance identifier (e.g. emr-prod-db)"
}

variable "rds_allocated_storage_gb" {
  type        = number
  description = "Allocated storage in GB — used to calculate low-storage threshold"
}

# ── API Gateway ───────────────────────────────────────────────────────────────

variable "api_gateway_name" {
  type        = string
  description = "REST API name for CloudWatch metrics"
}

variable "api_gateway_stage" {
  type        = string
  description = "API Gateway stage name"
}

# ── CloudFront ────────────────────────────────────────────────────────────────

variable "cloudfront_distribution_id" {
  type        = string
  description = "CloudFront distribution ID"
}

# ── NLB ───────────────────────────────────────────────────────────────────────

variable "nlb_arn_suffix" {
  type        = string
  description = "NLB ARN suffix for CloudWatch metrics (app/emr-prod-nlb/...)"
}

variable "target_group_arn_suffix" {
  type        = string
  description = "Target group ARN suffix for CloudWatch metrics"
}

variable "env" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "cloudfront_price_class" {
  type = string
}

variable "certificate_arn" {
  type        = string
  description = "ACM cert ARN — must be in us-east-1"
}

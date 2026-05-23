provider "aws" {
  region = "us-east-1" # primary — us-east-1 also satisfies the CloudFront ACM cert requirement
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region # us-west-2
}

locals {
  # Namespace secondary resources to avoid IAM global name collisions
  secondary_env = "${var.env}-${var.secondary_region}"
}

# ─────────────────────────────────────────────────────────────────────────────
# PRIMARY REGION (us-east-2)
# ─────────────────────────────────────────────────────────────────────────────

module "networking" {
  source             = "../../modules/networking"
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway
}

module "acm_api" {
  source            = "../../modules/acm"
  domain_name       = var.primary_api_domain_name
  use_existing_cert = var.use_existing_cert
  existing_cert_arn = var.primary_existing_cert_arn
}

module "acm_cloudfront" {
  source = "../../modules/acm"
  # No provider alias needed — default provider is already us-east-1 in prod

  domain_name       = var.frontend_domain
  use_existing_cert = var.use_existing_cert
  existing_cert_arn = var.cloudfront_cert_arn
}

module "secrets" {
  source      = "../../modules/secrets"
  env         = var.env
  db_password = var.db_password
  jwt_secret  = var.jwt_secret
}

module "ecr" {
  source     = "../../modules/ecr"
  repo_names = ["emr-api"]
}

module "rds" {
  source              = "../../modules/rds"
  env                 = var.env
  db_subnet_ids       = module.networking.private_subnet_ids
  rds_sg_id           = module.networking.rds_sg_id
  db_password         = var.db_password
  instance_class      = var.rds_instance_class
  allocated_storage   = var.rds_allocated_storage
  multi_az            = var.rds_multi_az
  deletion_protection = var.rds_deletion_protection
}

module "api_gateway" {
  source                   = "../../modules/api-gateway"
  env                      = var.env
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  certificate_arn          = module.acm_api.certificate_arn
  api_domain_name          = var.primary_api_domain_name
  cors_allow_origin        = "https://mallow.io"
  failover_domain_name     = "api.${var.root_domain}"
  failover_certificate_arn = module.acm_api.certificate_arn
}

module "ses" {
  source                 = "../../modules/ses"
  env                    = var.env
  domain                 = var.ses_domain
  create_route53_records = false
}

# ── Tenant Document Storage ───────────────────────────────────────────────────
# Primary bucket replicates to secondary. Secondary bucket is created further
# down under the SECONDARY REGION section.

module "storage" {
  source                 = "../../modules/storage"
  env                    = var.env
  cors_origins           = ["https://mallow.io"]
  enable_replication     = true
  replication_bucket_arn = module.storage_secondary.bucket_arn
}

# ── Agreement Document Storage ───────────────────────────────────────────────

module "agreements" {
  source = "../../modules/agreements"
  env    = var.env
}

module "ecs" {
  source                   = "../../modules/ecs"
  env                      = var.env
  ecr_image_url            = "${module.ecr.repo_urls["emr-api"]}:latest"
  db_secret_arn            = module.secrets.db_secret_arn
  jwt_secret_arn           = module.secrets.jwt_secret_arn
  private_subnet_ids       = module.networking.private_subnet_ids
  ecs_sg_id                = module.networking.ecs_sg_id
  target_group_arn         = module.api_gateway.target_group_arn
  desired_count            = var.ecs_desired_count
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  log_retention_days       = var.log_retention_days
  enable_bedrock           = true
  ses_identity_arns        = [module.ses.domain_identity_arn]
  s3_bucket_arns           = [module.storage.bucket_arn]
  document_s3_bucket       = module.storage.bucket_name
  enable_agreements_s3     = true
  agreement_s3_bucket_arn  = module.agreements.bucket_arn
  agreement_s3_bucket_name = module.agreements.bucket_name
  kms_key_arns             = [module.secrets.kms_key_arn]
}

module "frontend" {
  source                 = "../../modules/frontend"
  env                    = var.env
  domain_name            = var.frontend_domain
  cloudfront_price_class = var.cloudfront_price_class
  certificate_arn        = module.acm_cloudfront.certificate_arn
}

# ── Bastion Host (SSM Session Manager) ───────────────────────────────────────

module "bastion" {
  source           = "../../modules/bastion"
  env              = var.env
  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnet_ids[0]
  rds_sg_id        = module.networking.rds_sg_id
}

# ── Monitoring & Alerts ────────────────────────────────────────────────────────

module "monitoring" {
  source = "../../modules/monitoring"
  env    = var.env

  alert_email = var.alert_email

  ecs_cluster_name   = module.ecs.cluster_name
  ecs_service_name   = module.ecs.service_name
  ecs_desired_count  = var.ecs_desired_count
  ecs_log_group_name = "/ecs/emr-${var.env}"

  rds_instance_id          = module.rds.db_identifier
  rds_allocated_storage_gb = var.rds_allocated_storage

  api_gateway_name  = module.api_gateway.rest_api_name
  api_gateway_stage = module.api_gateway.stage_name

  cloudfront_distribution_id = module.frontend.distribution_id

  nlb_arn_suffix          = module.api_gateway.nlb_arn_suffix
  target_group_arn_suffix = module.api_gateway.target_group_arn_suffix
}

# ─────────────────────────────────────────────────────────────────────────────
# SECONDARY REGION (us-west-2) — S3 replication target only
# Compute/networking/database removed for cost savings (single tenant).
# Re-enable full secondary region when scaling to multiple tenants.
# ─────────────────────────────────────────────────────────────────────────────

module "storage_secondary" {
  source    = "../../modules/storage"
  providers = { aws = aws.secondary }
  env       = local.secondary_env
}

# ─────────────────────────────────────────────────────────────────────────────
# ROUTE 53 — single-region routing (global service, uses default provider)
# Replaces manual DNS: outputs NS records for registrar delegation.
# ─────────────────────────────────────────────────────────────────────────────

module "route53" {
  source = "../../modules/route53"

  root_domain       = var.root_domain
  api_target        = module.api_gateway.custom_domain_target
  cloudfront_domain = module.frontend.cloudfront_domain
  frontend_domain   = var.frontend_domain
}

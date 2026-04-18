provider "aws" {
  region = "us-east-2"
}

# CloudFront ACM certs must be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# ── Networking ────────────────────────────────────────────────────────────────

module "networking" {
  source             = "../../modules/networking"
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway
}

# ── ACM — API Gateway (us-east-2) ─────────────────────────────────────────────

module "acm_api" {
  source            = "../../modules/acm"
  domain_name       = var.api_domain_name
  use_existing_cert = var.use_existing_cert
  existing_cert_arn = var.existing_cert_arn
}

# ── ACM — CloudFront (us-east-1) ──────────────────────────────────────────────

module "acm_cloudfront" {
  source    = "../../modules/acm"
  providers = { aws = aws.us_east_1 }

  domain_name       = var.frontend_domain
  use_existing_cert = var.use_existing_cert
  existing_cert_arn = var.cloudfront_cert_arn
}

# ── Secrets ───────────────────────────────────────────────────────────────────

module "secrets" {
  source      = "../../modules/secrets"
  env         = var.env
  db_password = var.db_password
  jwt_secret  = var.jwt_secret
}

# ── ECR ───────────────────────────────────────────────────────────────────────

module "ecr" {
  source     = "../../modules/ecr"
  repo_names = ["emr-api"]
}

# ── RDS ───────────────────────────────────────────────────────────────────────

module "rds" {
  source              = "../../modules/rds"
  env                 = var.env
  db_subnet_ids       = module.networking.public_subnet_ids
  rds_sg_id           = module.networking.rds_sg_id
  db_password         = var.db_password
  instance_class      = var.rds_instance_class
  allocated_storage   = var.rds_allocated_storage
  multi_az            = var.rds_multi_az
  deletion_protection = var.rds_deletion_protection
  publicly_accessible = true
}

# ── API Gateway ───────────────────────────────────────────────────────────────

module "api_gateway" {
  source             = "../../modules/api-gateway"
  env                = var.env
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  certificate_arn    = module.acm_api.certificate_arn
  api_domain_name    = var.api_domain_name
  cors_allow_origin  = "https://dev.docli.io"
}

# ── Tenant Document Storage ───────────────────────────────────────────────────

module "storage" {
  source       = "../../modules/storage"
  env          = var.env
  cors_origins = ["https://dev.docli.io"]
}

# ── Agreement Document Storage ───────────────────────────────────────────────

module "agreements" {
  source = "../../modules/agreements"
  env    = var.env
}

# ── SES ───────────────────────────────────────────────────────────────────────
# DNS is external in dev — terraform apply outputs DKIM + verification records
# for manual addition at the registrar.

module "ses" {
  source                 = "../../modules/ses"
  env                    = var.env
  domain                 = var.ses_domain
  create_route53_records = false
}

# ── ECS ───────────────────────────────────────────────────────────────────────

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

# ── Direct RDS access (dev only) ─────────────────────────────────────────────

resource "aws_security_group_rule" "rds_from_developer" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = var.db_allowed_cidrs
  security_group_id = module.networking.rds_sg_id
}

# ── Frontend ──────────────────────────────────────────────────────────────────

module "frontend" {
  source                 = "../../modules/frontend"
  env                    = var.env
  domain_name            = var.frontend_domain
  cloudfront_price_class = var.cloudfront_price_class
  certificate_arn        = module.acm_cloudfront.certificate_arn
}

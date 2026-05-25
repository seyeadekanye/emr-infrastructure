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
  repo_names = ["emr-api", "emr-worker"]
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
  cors_allow_origin  = "https://dev.mallow.io"
}

# ── Tenant Document Storage ───────────────────────────────────────────────────

module "storage" {
  source       = "../../modules/storage"
  env          = var.env
  cors_origins = ["https://dev.mallow.io"]
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
  source                   = "../../modules/ses"
  env                      = var.env
  domain                   = var.ses_domain
  create_route53_records   = false
  webhook_subscription_url = "https://${var.api_domain_name}/api/v1/messaging/webhooks/ses"
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

  # ── Messaging platform (Slice 1a — 6c) ───────────────────────────────────
  # Real email sends are on in dev. SMS stays off (no End User Messaging
  # SMS provider in code yet; 10DLC paperwork not started — DESIGN.md §G).
  messaging_email_enabled           = true
  messaging_email_from              = "noreply@${var.ses_domain}"
  messaging_ses_config_set          = module.ses.configuration_set_name
  messaging_billing_notify_email    = var.messaging_billing_notify_email
  messaging_compliance_notify_email = var.messaging_compliance_notify_email
  messaging_mallowhq_billing_email  = var.messaging_mallowhq_billing_email
}

# ── ECS Worker (emr-worker — long-running @Scheduled jobs) ───────────────────
# Reuses module.ecs's cluster. No load balancer. Smaller task than the API.
# All four messaging @Scheduled kill switches default false here so the first
# deploy verifies the JVM boots without firing every scheduled bean across
# every tenant. Flip to true in a follow-up apply after observing a clean
# boot. See docs/messaging/DESIGN.md §3 and the emr-worker design report.

module "ecs_worker" {
  source             = "../../modules/ecs-worker"
  env                = var.env
  ecr_image_url      = "${module.ecr.repo_urls["emr-worker"]}:latest"
  cluster_id         = module.ecs.cluster_arn
  db_secret_arn      = module.secrets.db_secret_arn
  jwt_secret_arn     = module.secrets.jwt_secret_arn
  private_subnet_ids = module.networking.private_subnet_ids
  ecs_sg_id          = module.networking.ecs_sg_id
  # Scaled to 0: the messaging @Scheduled workers (MessageOutboxWorker,
  # AppointmentReminderWorker, TenantOnboardingSequenceWorker,
  # AuthExpirySweepJob) were collapsed into emr-api on 2026-05-25 — see
  # docs/messaging/CHANGELOG.md. The ECR repo, IAM roles, task def, and
  # service stay defined so we can revive emr-worker for future genuinely-
  # decoupled jobs (e.g. SQS consumer per DESIGN.md §D) without re-doing
  # the bootstrap. Flip back to 1 only after deciding what runs here.
  desired_count      = 0
  cpu                = 512
  memory             = 1024
  log_retention_days = var.log_retention_days

  enable_bedrock     = true
  ses_identity_arns  = [module.ses.domain_identity_arn]
  s3_bucket_arns     = [module.storage.bucket_arn]
  document_s3_bucket = module.storage.bucket_name
  kms_key_arns       = [module.secrets.kms_key_arn]

  # Same messaging env block as module.ecs — worker reads identical keys.
  messaging_email_enabled        = true
  messaging_email_from           = "noreply@${var.ses_domain}"
  messaging_ses_config_set       = module.ses.configuration_set_name
  messaging_billing_notify_email = var.messaging_billing_notify_email

  # First-deploy posture — all schedulers OFF until we see a clean boot.
  messaging_outbox_enabled            = false
  messaging_reminders_enabled         = false
  messaging_auth_expiry_enabled       = false
  messaging_tenant_onboarding_enabled = false
}

# ── Bastion Host (SSM Session Manager) ───────────────────────────────────────

module "bastion" {
  source           = "../../modules/bastion"
  env              = var.env
  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnet_ids[0]
  rds_sg_id        = module.networking.rds_sg_id
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

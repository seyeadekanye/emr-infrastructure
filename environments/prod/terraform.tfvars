env         = "prod"
root_domain = "mallow.io"

# ── Regions ───────────────────────────────────────────────────────────────────

secondary_region = "us-west-2"

# ── Networking ────────────────────────────────────────────────────────────────

vpc_cidr           = "10.20.0.0/22"
single_nat_gateway = true # single tenant — HA NAT not needed

secondary_vpc_cidr = "10.30.0.0/22" # must not overlap with primary or dev

# ── RDS ───────────────────────────────────────────────────────────────────────

rds_instance_class      = "db.t3.small"
rds_allocated_storage   = 50
rds_multi_az            = false # single tenant — re-enable when scaling
rds_deletion_protection = true

# ── ECS ───────────────────────────────────────────────────────────────────────

ecs_desired_count           = 1 # single tenant — scale up when adding tenants
secondary_ecs_desired_count = 1 # warm standby — scale to 2 during failover
ecs_cpu                     = 1024
ecs_memory                  = 2048
log_retention_days          = 90

# ── Frontend ──────────────────────────────────────────────────────────────────

cloudfront_price_class = "PriceClass_100" # US/Canada/Europe — sufficient for single US tenant
frontend_domain        = "mallow.io"

# ── ACM ───────────────────────────────────────────────────────────────────────
# Regional domains used as API GW custom domains (not user-facing directly).
# Route53 provides the user-facing api.mallow.io via failover routing.

primary_api_domain_name   = "api-us-east-1.mallow.io"
secondary_api_domain_name = "api-us-west-2.mallow.io"

use_existing_cert           = true
primary_existing_cert_arn   = "arn:aws:acm:us-east-1:736822756246:certificate/2373e2ef-b365-48bb-99cd-5b0e2a42a0fa"
secondary_existing_cert_arn = "arn:aws:acm:us-west-2:736822756246:certificate/382a85a1-d96b-4379-8240-20fdbd7874fa"
cloudfront_cert_arn         = "arn:aws:acm:us-east-1:736822756246:certificate/2373e2ef-b365-48bb-99cd-5b0e2a42a0fa"

# ── SES ───────────────────────────────────────────────────────────────────────

ses_domain = "mallowhealth.com"

# ── Monitoring ────────────────────────────────────────────────────────────────

alert_email = "support@mallowhealth.com"

# db_password and jwt_secret are passed via -var in CI (never committed)

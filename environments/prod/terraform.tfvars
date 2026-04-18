env         = "prod"
root_domain = "docli.io"

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
frontend_domain        = "docli.io"

# ── ACM ───────────────────────────────────────────────────────────────────────
# Regional domains used as API GW custom domains (not user-facing directly).
# Route53 provides the user-facing api.docli.io via failover routing.

primary_api_domain_name   = "api-us-east-1.docli.io"
secondary_api_domain_name = "api-us-west-2.docli.io"

use_existing_cert           = true
primary_existing_cert_arn   = "arn:aws:acm:us-east-1:736822756246:certificate/5604572f-9220-4709-bb32-b24d01184022"
secondary_existing_cert_arn = "arn:aws:acm:us-west-2:736822756246:certificate/33bdeeb7-d05b-43b9-99aa-439b72cbfb9c"
cloudfront_cert_arn         = "arn:aws:acm:us-east-1:736822756246:certificate/5604572f-9220-4709-bb32-b24d01184022"

# db_password and jwt_secret are passed via -var in CI (never committed)

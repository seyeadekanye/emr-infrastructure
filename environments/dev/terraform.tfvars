env                = "dev"
vpc_cidr           = "10.10.0.0/24"
single_nat_gateway = true

rds_instance_class      = "db.t3.micro"
rds_allocated_storage   = 20
rds_multi_az            = false
rds_deletion_protection = false

ecs_desired_count  = 1
ecs_cpu            = 1024
ecs_memory         = 2048
log_retention_days = 14

cloudfront_price_class = "PriceClass_100"
api_domain_name        = "api-dev.docli.io"
frontend_domain        = "dev.docli.io"

use_existing_cert   = true
existing_cert_arn   = "arn:aws:acm:us-east-2:736822756246:certificate/8d2a6abe-6b38-4d69-af95-77ceb570dba1"
cloudfront_cert_arn = "arn:aws:acm:us-east-1:736822756246:certificate/5639afd8-c7d0-4761-b1d5-795c0096e31e"

ses_domain = "dev.docli.io"

db_allowed_cidrs = ["0.0.0.0/0"]

# db_password and jwt_secret are passed via -var in CI (never committed)

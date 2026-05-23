# Module Architecture Reference

Detailed input/output/provision specs for each Terraform module.

---

## `modules/networking`

```
Inputs:
  env                string
  vpc_cidr           string
  az_count           number
  single_nat_gateway bool

Outputs:
  vpc_id
  private_subnet_ids
  public_subnet_ids
  ecs_sg_id
  rds_sg_id

Provisions:
  VPC (DNS hostnames + resolution enabled)
  2 public subnets across 2 AZs  → IGW route
  2 private subnets across 2 AZs → NAT GW route
  Internet Gateway
  NAT Gateway(s):
    dev  → 1 (single_nat_gateway = true,  ~$32/mo saving)
    prod → 2 (one per AZ for HA)
  Elastic IPs for NAT GWs
  Route tables (public + private)
  Security Groups:
    ecs_sg:  ingress TCP 8080 from 0.0.0.0/0; egress all
             (NLB is internal; ECS tasks need outbound for ECR/Secrets Manager)
    rds_sg:  ingress TCP 3306 from ecs_sg only; egress none
```

---

## `modules/acm`

```
Inputs:
  domain_name        string   # e.g. api.mallow.io
  use_existing_cert  bool
  existing_cert_arn  string   # used when use_existing_cert = true

Outputs:
  certificate_arn
  validation_cname   # output for manual DNS entry at registrar (new cert path only)

Notes:
  When use_existing_cert = true:
    data "aws_acm_certificate" looks up the existing cert by domain.

  When use_existing_cert = false (stub, commented out by default):
    aws_acm_certificate + aws_acm_certificate_validation
    Outputs the CNAME validation record → operator adds at registrar → cert issues.

  API Gateway custom domain certs must be in the same region as the API (us-east-2).
  CloudFront certs must be in us-east-1 — handled separately in the frontend module.
```

---

## `modules/secrets`

```
Inputs:
  env          string
  db_password  string (sensitive)
  jwt_secret   string (sensitive)

Outputs:
  db_secret_arn
  jwt_secret_arn
  kms_key_arn

Provisions:
  KMS key: emr-{env}-secrets
  Secrets Manager secret: emr/{env}/db  → JSON { "password": "..." }
  Secrets Manager secret: emr/{env}/jwt → JSON { "secret": "..." }
  Rotation: disabled (manual — can enable later)
```

---

## `modules/ecr`

```
Inputs:
  repo_names   list(string)

Outputs:
  repo_urls    map(string)

Provisions (per repo):
  ECR repository
  Image scanning on push enabled
  Lifecycle policy:
    - Keep last 10 tagged images
    - Expire untagged images after 7 days
```

---

## `modules/rds`

```
Inputs:
  env                  string
  db_subnet_ids        list(string)
  rds_sg_id            string
  db_secret_arn        string
  instance_class       string
  allocated_storage    number
  multi_az             bool
  deletion_protection  bool

Outputs:
  db_endpoint
  db_port
  db_name

Provisions:
  DB subnet group (private subnets in EMR VPC)
  DB parameter group:
    character_set_server = utf8mb4
    collation_server     = utf8mb4_unicode_ci
    slow_query_log       = 1
    long_query_time      = 2
  RDS MariaDB 10.11:
    Storage encrypted (KMS)
    Automated backups: 7-day retention
    Maintenance window: sun:03:00-sun:04:00
    Credentials via manage_master_user_password (Secrets Manager native)
    dev:  db.t3.micro, 20GB,  single-AZ, deletion_protection = false
    prod: db.t3.small, 50GB,  multi-AZ,  deletion_protection = true

Note: The emr_control (control plane) database is provisioned in-app by
      TenantProvisioningService at startup. Terraform provisions the shared
      RDS instance only; the application manages the database-level objects.
```

---

## `modules/ecs`

```
Inputs:
  env                  string
  ecr_image_url        string
  db_secret_arn        string
  jwt_secret_arn       string
  private_subnet_ids   list(string)
  ecs_sg_id            string
  target_group_arn     string
  desired_count        number
  cpu                  number
  memory               number

Outputs:
  cluster_arn
  service_name
  task_exec_role_arn

Provisions:
  ECS Cluster (Container Insights enabled)

  IAM Task Execution Role:
    AmazonECSTaskExecutionRolePolicy (managed)
    Inline: logs:CreateLogGroup + logs:PutLogEvents (scoped to /ecs/emr-{env})
    Inline: secretsmanager:GetSecretValue (scoped to emr/{env}/*)

  Task Definition:
    Fargate, Linux/X86_64
    CPU: {cpu}  Memory: {memory}
    Container: emr-api, port 8080
    Environment vars:
      SPRING_PROFILES_ACTIVE = {env}
    Secrets (injected from Secrets Manager at task start):
      DB_PASSWORD ← emr/{env}/db::password
      JWT_SECRET  ← emr/{env}/jwt::secret
    Log configuration:
      awslogs → /ecs/emr-{env}, stream prefix: api

  ECS Service:
    Fargate, private subnets
    Desired count: {desired_count}
    Deployment: min 50% healthy, max 200%
    Load balancer: target_group_arn → container port 8080
    Health check grace period: 120s

  CloudWatch Log Group:
    /ecs/emr-{env}
    dev  retention: 14 days
    prod retention: 90 days
```

---

## `modules/api-gateway`

```
Inputs:
  env                  string
  private_subnet_ids   list(string)
  target_group_port    number        # 8080
  certificate_arn      string
  api_domain_name      string        # e.g. api.mallow.io
  vpc_id               string

Outputs:
  api_invoke_url        # raw execute-api URL (fallback)
  api_custom_domain     # the configured custom domain
  custom_domain_target  # CNAME value to set at registrar
  nlb_dns               # internal NLB DNS (not public-facing)

Provisions:
  NLB (internal, private subnets, cross-zone load balancing enabled)
  Target Group:
    TCP port 8080
    Health check: HTTP GET /actuator/health, 200 expected
    Deregistration delay: 30s
  NLB Listener: TCP 8080 → target group

  VPC Link (REST API v1) → NLB

  API Gateway REST API (Regional):
    Resource: /{proxy+}
    Method:   ANY (no auth at GW layer — handled by Spring Security)
    Integration: HTTP_PROXY via VPC Link → http://{nlb_dns}:8080/{proxy}
    Stage: {env}
      Access logging → CloudWatch
      Throttling: 1000 RPS burst, 500 RPS steady (configurable per env)

  API Gateway Custom Domain:
    Domain: {api_domain_name}
    Certificate: {certificate_arn}
    Base path mapping: / → {env} stage
    Output: custom_domain_target → operator adds CNAME at registrar
```

---

## `modules/frontend`

```
Inputs:
  env                    string
  domain_name            string        # e.g. mallow.io
  cloudfront_price_class string
  certificate_arn        string        # must be in us-east-1

Outputs:
  cloudfront_domain     # add CNAME at registrar: domain_name → this value
  s3_bucket_name
  distribution_id       # used for cache invalidation in deploy pipeline

Provisions:
  S3 Bucket:
    Private (block all public access)
    Versioning enabled
    AES-256 encryption
    Lifecycle: expire non-current versions after 30 days

  CloudFront Origin Access Control (OAC)

  S3 Bucket Policy:
    Allow CloudFront OAC principal GetObject only

  CloudFront Distribution:
    Origin: S3 via OAC
    Alias: {domain_name}
    ACM cert: {certificate_arn} (must be us-east-1)
    Viewer protocol: redirect-to-https
    HTTP/2 + HTTP/3
    Default root object: index.html
    Custom error responses:
      403 → /index.html, 200  (S3 returns 403 for missing keys → SPA routing)
      404 → /index.html, 200
    Cache behaviors:
      /assets/*   → CachingOptimized (long TTL, content-hashed filenames)
      /index.html → CachingDisabled  (always fetch latest)
    Price class: {cloudfront_price_class}
      dev:  PriceClass_100 (US/Europe — lower cost)
      prod: PriceClass_All
```

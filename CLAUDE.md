# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Terraform infrastructure-as-code for the EMR platform on AWS. Provisions networking, ECS (Fargate), RDS (MariaDB), API Gateway, CloudFront/S3 frontend, ECR, ACM, Secrets Manager, and Route53 across `dev` (single-region) and `prod` (active-passive multi-region) environments.

## Commands

### Bootstrap (one-time — creates S3 state bucket + DynamoDB lock table)
```bash
cd bootstrap && terraform init && terraform apply
```

### Per-environment workflow
```bash
cd environments/dev        # or environments/prod
terraform init             # connect to S3 backend
terraform fmt -check       # formatting check
terraform validate         # syntax/type validation
terraform plan             # review before applying
terraform apply
```

## Repository Structure

```
emr-infrastructure/
├── bootstrap/             # Run once: S3 state bucket + DynamoDB lock table
├── compliance/            # Run once: CloudTrail + GuardDuty (account-level, HIPAA)
├── modules/
│   ├── networking/        # VPC, subnets, IGW, NAT GWs, route tables, SGs
│   ├── ecr/               # ECR repos + lifecycle policies + cross-region replication
│   ├── secrets/           # Secrets Manager (DB password, JWT) + KMS key + cross-region replicas
│   ├── rds/               # MariaDB 10.11 instance, subnet group, param group
│   ├── rds-replica/       # Cross-region read replica (promote manually during failover)
│   ├── ecs/               # Fargate cluster, task definition, service, IAM roles
│   ├── api-gateway/       # NLB, VPC link, REST API (proxy), custom domain
│   ├── acm/               # Data source for existing cert + stub for new
│   ├── frontend/          # S3 bucket, CloudFront OAC distribution
│   ├── route53/           # Hosted zone, health checks, failover routing (prod only)
│   ├── ses/               # Domain identity, DKIM, bounce/complaint SNS topic
│   ├── storage/           # S3 bucket for tenant documents (per-region, cross-region replication in prod)
│   └── compliance/        # CloudTrail (multi-region, KMS-encrypted) + GuardDuty + alert SNS topic
└── environments/
    ├── dev/               # Single-region (us-east-2)
    └── prod/              # Multi-region: primary us-east-2 + secondary us-west-2
```

Separate state files per environment: `emr-terraform-state-736822756246/{env}.tfstate`

## Naming Convention

All resources: `emr-{env}-{resource}`. ECR is shared (`emr-api`). Secrets: `emr/{env}/db` and `emr/{env}/jwt`.

| Resource | Dev | Prod |
|---|---|---|
| VPC | `emr-dev-vpc` | `emr-prod-vpc` |
| ECS Cluster/Service | `emr-dev-cluster` / `emr-dev-api` | `emr-prod-cluster` / `emr-prod-api` |
| NLB | `emr-dev-nlb` | `emr-prod-nlb` |
| RDS | `emr-dev-db` | `emr-prod-db` |
| API Gateway | `emr-dev-api-gw` | `emr-prod-api-gw` |
| S3 / CloudFront | `emr-dev-frontend` | `emr-prod-frontend` |
| Log Group | `/ecs/emr-dev` | `/ecs/emr-prod` |

## Key Decisions

| # | Decision |
|---|---|
| 1 | **Prod**: Route53 hosted zone for `mallow.io` — registrar delegates to Route53 NS records. **Dev**: DNS still external (registrar), Terraform outputs CNAME values |
| 2 | **Prod**: API GW custom domains are region-scoped (`api-us-east-2.mallow.io`, `api-us-west-2.mallow.io`). Route53 failover provides user-facing `api.mallow.io`. **Dev**: single API GW custom domain (`api-dev.mallow.io`) pointed at manually |
| 3 | ACM: existing cert via data source by default; new-cert provisioning is a commented stub |
| 4 | Control plane DB (`emr_control`) is managed in-app by `TenantProvisioningService` — not Terraform scope |
| 5 | Jitsi is out of scope |
| 6 | Separate Terraform state file per environment |
| 7 | Multi-region is prod-only. Dev stays single-region to keep costs down |
| 8 | Active-passive failover (not active-active). Secondary region runs warm standby (`desired_count=1`) |
| 9 | RDS failover is manual: promote read replica with `aws rds promote-read-replica`, then redeploy ECS with new DB endpoint |

## Architecture Notes

**Traffic path (prod):**
```
Frontend: Registrar → Route53 (ALIAS) → CloudFront → S3
API:      Registrar → Route53 NS delegation → Route53 failover (api.mallow.io)
              PRIMARY  → api-us-east-2.mallow.io → API GW → NLB → ECS → RDS (primary)
              SECONDARY → api-us-west-2.mallow.io → API GW → NLB → ECS → RDS (replica)
```

**ACM certs needed (3 total in prod):**
- `api-us-east-1.mallow.io` in `us-east-1` — primary API GW (same region as default provider)
- `api-us-west-2.mallow.io` in `us-west-2` — secondary API GW
- `mallow.io` (wildcard `*.mallow.io` recommended) in `us-east-1` — CloudFront (can reuse the same cert as primary API GW if using wildcard)

**Secondary region IAM naming:** All secondary modules receive `env = "prod-us-west-2"` (via `local.secondary_env`) to avoid IAM global name collisions with primary resources (`emr-prod-*` vs `emr-prod-us-west-2-*`).

**Secrets in secondary region:** The `secrets` module replicates to `us-west-2`. Secondary ECS tasks read from the replica ARNs via `module.secrets.replica_db_secret_arns[var.secondary_region]` — the IAM policy in the ECS module auto-scopes to whichever region the task runs in.

**ECR replication:** Account-level replication pushes all images from `us-east-2` to `us-west-2` automatically on push. Secondary ECS uses the same ECR image URL (cross-region pull).

**RDS failover (manual steps):**
1. `aws rds promote-read-replica --db-instance-identifier emr-prod-us-west-2-db-replica`
2. Redeploy secondary ECS service with updated `DB_HOST` env var
3. Route53 health checks automatically shift `api.mallow.io` to secondary once ECS is healthy

**Tenant document storage:** `emr-{env}-documents` bucket per region. Private, versioned, AES-256 encrypted. Non-current versions tier to Standard-IA at 30 days, Glacier at 90 days. In prod, the primary bucket replicates to the secondary region bucket (`emr-prod-us-west-2-documents`) via S3 cross-region replication. Each ECS task role gets scoped `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject`/`s3:ListBucket` access to its region's bucket.

**SES:** Domain verified in both environments. Prod auto-creates DKIM + verification DNS records in Route53. Dev outputs them for manual addition at the registrar. Both ECS environments get `ses:SendEmail` on the task role (not execution role) scoped to the verified domain ARN. Moving out of the SES sandbox requires a one-time manual AWS Support request — Terraform does not manage this.

**ECS IAM roles — two distinct roles per environment:**
- *Execution role* (`emr-{env}-task-exec-role`) — used by ECS infrastructure to pull images and inject secrets. Managed by AWS.
- *Task role* (`emr-{env}-task-role`) — assumed by the running container. Grants application-level AWS API access (currently SES). Add future policies here as the app grows.

**Secrets injection:** DB password and JWT secret are pulled from Secrets Manager at ECS task start. The task execution role is scoped to `emr/{env}/*`.

**Auth:** No auth at the API Gateway layer — handled entirely by Spring Security in the application.

**RDS boundary:** Terraform provisions the RDS instance only. The `emr_control` database and all schema objects are managed by `MultiTenantFlywayRunner` at application startup.

## Environment Differences

| Variable | Dev | Prod (primary) | Prod (secondary) |
|---|---|---|---|
| Region | `us-east-2` | `us-east-1` | `us-west-2` |
| `vpc_cidr` | `10.10.0.0/24` | `10.20.0.0/22` | `10.30.0.0/22` |
| `single_nat_gateway` | `true` | `false` (HA) | `true` (standby) |
| `rds_instance_class` | `db.t3.micro` | `db.t3.small` | `db.t3.small` (replica) |
| `rds_multi_az` | `false` | `true` | N/A (replica) |
| `ecs_desired_count` | `1` | `2` | `1` (warm standby) |
| `ecs_cpu` / `ecs_memory` | `1024` / `2048` | `2048` / `4096` | `2048` / `4096` |
| `log_retention_days` | `14` | `90` | `90` |
| `cloudfront_price_class` | `PriceClass_100` | `PriceClass_All` | N/A (CloudFront is global) |
| API domain | `api-dev.mallow.io` | `api-us-east-1.mallow.io` | `api-us-west-2.mallow.io` |
| User-facing API | direct CNAME at registrar | `api.mallow.io` via Route53 | failover target |
| `frontend_domain` | `dev.mallow.io` | `mallow.io` | — |
| DNS | External registrar | Route53 (`mallow.io` hosted zone) | — |

## AWS Account Reference

| | Value |
|---|---|
| Account ID | `736822756246` |
| Dev primary region | `us-east-2` |
| Prod primary region | `us-east-1` |
| Prod secondary region | `us-west-2` |
| CloudFront ACM region | `us-east-1` (required by CloudFront — same as prod primary, no extra cert needed) |

## CI/CD (Phase 3)

GitHub Actions: PRs run `fmt -check` + `validate` + `plan` (plan posted as PR comment via tfcmt). Merges to `main` auto-apply dev; prod requires manual approval via GitHub environment protection.

Sensitive vars (`db_password`, `jwt_secret`, AWS credentials) are passed as `-var` flags from GitHub Actions secrets — never committed to `.tfvars`.

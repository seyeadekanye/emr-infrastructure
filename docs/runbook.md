# Operations Runbook

## Phase 0 — Bootstrap (one-time, ~10 min)

Create the Terraform remote state backend before any environment is provisioned.
These are the only resources ever created outside of Terraform.

```bash
cd bootstrap
terraform init
terraform apply
```

Creates:
- S3 bucket: `emr-terraform-state-736822756246` (versioned, AES-256, lifecycle rules)
- DynamoDB table: `emr-terraform-locks` (PAY_PER_REQUEST billing)

---

## Phase 1 — Dev environment (~20 min apply)

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

**Post-apply checklist:**
1. Add CNAME at registrar: `api-dev.docli.io` → value from `custom_domain_target` output
2. Add CNAME at registrar: `dev.docli.io` → value from `cloudfront_domain` output
3. Update `VITE_JAVA_API_URL` in frontend `.env` to new API custom domain
4. Run Flyway migrations against new RDS instance
5. Seed `emr_control` DB — handled automatically by `MultiTenantFlywayRunner` on app startup
6. Register first tenant in `tenant_registry`
7. Deploy backend image to new ECS service, smoke test all endpoints
8. Decommission old manually-provisioned resources once validated

---

## Phase 2 — Prod environment

After dev is validated (recommended: 2–4 weeks of parallel running):

```bash
cd environments/prod
terraform init
terraform apply
```

**Gates before applying prod:**
- Confirm `deletion_protection = true` on RDS
- Confirm `prevent_destroy = true` lifecycle blocks on RDS and S3
- Confirm multi-AZ and backup retention settings
- Confirm `ecs_desired_count = 2` for zero-downtime deploys

---

## What Terraform Fixed vs Prior Manual Setup

| Gap | Before | After |
|---|---|---|
| DB credentials | Plaintext in `application.yml` | Secrets Manager, injected at ECS task start |
| JWT secret | Plaintext in `application.yml` | Secrets Manager |
| CloudFront → S3 | Legacy OAI | OAC (current AWS best practice) |
| S3 bucket | Accessible via public S3 URL | Fully private, OAC only |
| RDS subnet group | Default VPC subnet group | Dedicated subnet group in EMR VPC |
| ECS task execution role | No attached managed policies | Correctly scoped IAM policies |
| Naming | Inconsistent (`supervise-me-*`) | Consistent `emr-{env}-*` |
| Log retention | Manual, 14 days flat | Codified, env-specific (14d dev / 90d prod) |
| Dev cost | 2 NAT GWs (~$64/mo) | 1 NAT GW for dev (~$32/mo) |
| ECR lifecycle | No cleanup policy | Auto-expire untagged after 7 days |
| Image scanning | Not enabled | Enabled on push |
| RDS encryption | Unknown | KMS encryption at rest enforced |

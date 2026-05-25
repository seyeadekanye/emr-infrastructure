terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ── CloudWatch Log Group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/emr-${var.env}"
  retention_in_days = var.log_retention_days
}

# ── IAM Task Execution Role ───────────────────────────────────────────────────

resource "aws_iam_role" "task_exec" {
  name = "emr-${var.env}-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec_managed" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_exec_inline" {
  name = "emr-${var.env}-task-exec-inline"
  role = aws_iam_role.task_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/emr-${var.env}:*"
      },
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:emr/${var.env}/*"
      }
      ], length(var.kms_key_arns) > 0 ? [{
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = var.kms_key_arns
    }] : [])
  })
}

# ── IAM Task Role (application permissions) ──────────────────────────────────
# Distinct from the execution role. This role is assumed by the running container
# and governs what AWS APIs the application code can call.

resource "aws_iam_role" "task" {
  name = "emr-${var.env}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "task_ses" {
  count = length(var.ses_identity_arns) > 0 ? 1 : 0
  name  = "emr-${var.env}-task-ses"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = var.ses_identity_arns
    }]
  })
}

# ── SNS Publish (Slice 1c — SMS via SNS) ──────────────────────────────────────
# Gated by var.messaging_grant_sns_publish so the policy isn't attached until
# the operator has decided to enable SMS-via-SNS in this environment. SNS
# direct-publish to phone numbers requires Resource=* — the API doesn't model
# per-number ARNs.
resource "aws_iam_role_policy" "task_sns_publish" {
  count = var.messaging_grant_sns_publish ? 1 : 0
  name  = "emr-${var.env}-task-sns-publish"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "task_bedrock" {
  count = var.enable_bedrock ? 1 : 0
  name  = "emr-${var.env}-task-bedrock"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = [
        "arn:aws:bedrock:*::foundation-model/*",
        "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "task_s3" {
  count = length(var.s3_bucket_arns) > 0 ? 1 : 0
  name  = "emr-${var.env}-task-s3"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [for arn in var.s3_bucket_arns : "${arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.s3_bucket_arns
      }
    ]
  })
}

resource "aws_iam_role_policy" "task_agreements_s3" {
  count = var.enable_agreements_s3 ? 1 : 0
  name  = "emr-${var.env}-task-agreements-s3"
  role  = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:PutObjectRetention",
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      Resource = "${var.agreement_s3_bucket_arn}/*"
    }]
  })
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "emr-${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ── Task Definition ───────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "api" {
  family                   = "emr-${var.env}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name         = "emr-api"
    image        = var.ecr_image_url
    essential    = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]

    environment = concat([
      { name = "SPRING_PROFILES_ACTIVE", value = var.env }
      ], var.document_s3_bucket != "" ? [
      { name = "DOCUMENT_S3_BUCKET", value = var.document_s3_bucket }
      ] : [], var.agreement_s3_bucket_name != "" ? [
      { name = "AGREEMENT_S3_BUCKET", value = var.agreement_s3_bucket_name }
      ] : [],
      # ── Messaging platform (Slice 1a — 6c) ───────────────────────────────
      # Every var is optional with safe defaults — the messaging stack stays
      # in log-only mode until messaging_email_enabled / messaging_sms_enabled
      # are flipped. Defaults map to the application-{env}.yml @Value defaults.
      [
        { name = "EMAIL_ENABLED", value = tostring(var.messaging_email_enabled) },
        { name = "SMS_ENABLED", value = tostring(var.messaging_sms_enabled) },
        { name = "SMS_PROVIDER", value = var.messaging_sms_provider },
      ],
      var.messaging_email_from != "" ? [{ name = "EMAIL_FROM", value = var.messaging_email_from }] : [],
      var.messaging_ses_config_set != "" ? [{ name = "MESSAGING_SES_CONFIG_SET", value = var.messaging_ses_config_set }] : [],
      var.messaging_billing_notify_email != "" ? [{ name = "MESSAGING_BILLING_NOTIFY_EMAIL", value = var.messaging_billing_notify_email }] : [],
      var.messaging_compliance_notify_email != "" ? [{ name = "MESSAGING_COMPLIANCE_NOTIFY_EMAIL", value = var.messaging_compliance_notify_email }] : [],
      var.messaging_mallowhq_billing_email != "" ? [{ name = "MESSAGING_MALLOWHQ_BILLING_EMAIL", value = var.messaging_mallowhq_billing_email }] : []
    )

    # NOTE: Every secret the application reads MUST be listed here. The
    # multi-tenant app's bootstrap reads CONTROL_PLANE_DB_PASSWORD and
    # DEFAULT_TENANT_DB_PASSWORD in addition to the primary DB_PASSWORD. They
    # all source from the same db secret JSON (which has a `password` key).
    # Historically these two were injected by the CI deploy script out of
    # band; consolidating them here makes Terraform-rendered task defs
    # self-sufficient and survives Block A's env-var change.
    secrets = [
      { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
      { name = "JWT_SECRET", valueFrom = "${var.jwt_secret_arn}:secret::" },
      { name = "CONTROL_PLANE_DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
      { name = "DEFAULT_TENANT_DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/emr-${var.env}"
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "api"
      }
    }
  }])
}

# ── ECS Service ───────────────────────────────────────────────────────────────

resource "aws_ecs_service" "api" {
  name            = "emr-${var.env}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_sg_id]
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "emr-api"
    container_port   = 8080
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 120

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_iam_role_policy_attachment.task_exec_managed]
}

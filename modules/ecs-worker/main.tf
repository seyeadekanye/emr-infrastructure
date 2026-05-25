terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────────────────────
# emr-worker — long-running Fargate service running the Spring @Scheduled jobs.
#
# Mirrors modules/ecs (the API) but:
#   - no load balancer (worker has no HTTP surface;
#     spring.main.web-application-type=none in application.yml)
#   - smaller default task size (workers idle most of their cadence)
#   - separate log group so CloudWatch Insights queries don't compete with
#     the high-volume API access logs
#   - shares the emr-${env}-cluster passed in via var.cluster_id
#
# See /Users/eomotosho/Documents/Github/git-project-linker/docs/messaging/DESIGN.md §3
# for the module boundaries this maps to.
# ─────────────────────────────────────────────────────────────────────────────

# ── CloudWatch Log Group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/emr-${var.env}-worker"
  retention_in_days = var.log_retention_days
}

# ── IAM Task Execution Role ───────────────────────────────────────────────────

resource "aws_iam_role" "task_exec" {
  name = "emr-${var.env}-worker-task-exec-role"

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
  name = "emr-${var.env}-worker-task-exec-inline"
  role = aws_iam_role.task_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/emr-${var.env}-worker:*"
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
# Mirrors modules/ecs grants. Worker invokes MessageService → SesEmailProvider,
# SnsSmsProvider, S3 (document templates), Bedrock (AI rendering). Diverge from
# this only if the API gets a permission the worker provably doesn't need.

resource "aws_iam_role" "task" {
  name = "emr-${var.env}-worker-task-role"

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
  name  = "emr-${var.env}-worker-task-ses"
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

resource "aws_iam_role_policy" "task_sns_publish" {
  count = var.messaging_grant_sns_publish ? 1 : 0
  name  = "emr-${var.env}-worker-task-sns-publish"
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
  name  = "emr-${var.env}-worker-task-bedrock"
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
  name  = "emr-${var.env}-worker-task-s3"
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

# ── Task Definition ───────────────────────────────────────────────────────────
# Env block tracks modules/ecs/main.tf's messaging section so the application
# resolves identical @Value defaults. Per-job kill switches at the end give
# operators a way to spin the worker up without firing every @Scheduled bean
# at once on first deploy (see Risks §9 of the design report).

resource "aws_ecs_task_definition" "worker" {
  family                   = "emr-${var.env}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "emr-worker"
    image     = var.ecr_image_url
    essential = true
    # No portMappings.

    environment = concat([
      { name = "SPRING_PROFILES_ACTIVE", value = var.env }
      ], var.document_s3_bucket != "" ? [
      { name = "DOCUMENT_S3_BUCKET", value = var.document_s3_bucket }
      ] : [],
      [
        # DB usernames — set explicitly. emr-api runs fine with just its
        # application-dev.yml defaults, but emr-worker's first-boot resolved
        # the control-plane username to "admin" instead of the yml's
        # `emradmin` default. Belt-and-suspenders: force the right value.
        { name = "CONTROL_PLANE_DB_USERNAME", value = var.db_username },
        { name = "DEFAULT_TENANT_DB_USERNAME", value = var.db_username },

        # Messaging — mirrors modules/ecs env block.
        { name = "EMAIL_ENABLED", value = tostring(var.messaging_email_enabled) },
        { name = "SMS_ENABLED", value = tostring(var.messaging_sms_enabled) },
        { name = "SMS_PROVIDER", value = var.messaging_sms_provider },

        # Worker-only kill switches. Default false in this module so first-time
        # deploys verify the JVM boots before firing every scheduled bean
        # across every tenant. Flip in environments/<env>/main.tf after a
        # clean boot is observed.
        { name = "MESSAGING_OUTBOX_ENABLED", value = tostring(var.messaging_outbox_enabled) },
        { name = "MESSAGING_REMINDERS_ENABLED", value = tostring(var.messaging_reminders_enabled) },
        { name = "MESSAGING_AUTH_EXPIRY_ENABLED", value = tostring(var.messaging_auth_expiry_enabled) },
        { name = "MESSAGING_TENANT_ONBOARDING_ENABLED", value = tostring(var.messaging_tenant_onboarding_enabled) },
      ],
      var.messaging_email_from != "" ? [{ name = "EMAIL_FROM", value = var.messaging_email_from }] : [],
      var.messaging_ses_config_set != "" ? [{ name = "MESSAGING_SES_CONFIG_SET", value = var.messaging_ses_config_set }] : [],
      var.messaging_billing_notify_email != "" ? [{ name = "MESSAGING_BILLING_NOTIFY_EMAIL", value = var.messaging_billing_notify_email }] : []
    )

    secrets = [
      { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
      { name = "JWT_SECRET", valueFrom = "${var.jwt_secret_arn}:secret::" },
      { name = "CONTROL_PLANE_DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
      { name = "DEFAULT_TENANT_DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/emr-${var.env}-worker"
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "worker"
      }
    }
  }])
}

# ── ECS Service ───────────────────────────────────────────────────────────────
# No load_balancer, no health_check_grace_period_seconds (no LB).
# deployment_minimum_healthy_percent=0 lets a single-instance worker drain
# fully before the replacement starts — safe because MessageOutboxWorker is
# pull-based, so a brief gap just delays the next 15s drain.

resource "aws_ecs_service" "worker" {
  name            = "emr-${var.env}-worker"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_sg_id]
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_iam_role_policy_attachment.task_exec_managed]
}

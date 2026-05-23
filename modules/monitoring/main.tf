terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# SNS Topics
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "critical" {
  name = "emr-${var.env}-critical-alerts"
}

resource "aws_sns_topic" "warning" {
  name = "emr-${var.env}-warning-alerts"
}

resource "aws_sns_topic_subscription" "critical_email" {
  topic_arn = aws_sns_topic.critical.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "warning_email" {
  topic_arn = aws_sns_topic.warning.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ─────────────────────────────────────────────────────────────────────────────
# ECS Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "emr-${var.env}-ecs-cpu-high"
  alarm_description   = "ECS CPU utilization > 80%"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "emr-${var.env}-ecs-memory-high"
  alarm_description   = "ECS memory utilization > 85%"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_no_running_tasks" {
  alarm_name          = "emr-${var.env}-ecs-no-running-tasks"
  alarm_description   = "No ECS tasks running — complete outage"
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.critical.arn]
  ok_actions          = [aws_sns_topic.critical.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_task_count_low" {
  alarm_name          = "emr-${var.env}-ecs-task-count-low"
  alarm_description   = "Running tasks below desired count"
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.ecs_desired_count
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# RDS Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "emr-${var.env}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization > 80%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "emr-${var.env}-rds-storage-low"
  alarm_description   = "RDS free storage < 20% of allocated"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.rds_allocated_storage_gb * 1024 * 1024 * 1024 * 0.2 # 20% in bytes
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.critical.arn]
  ok_actions          = [aws_sns_topic.critical.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "emr-${var.env}-rds-connections-high"
  alarm_description   = "RDS connections > 80 (approaching limit for small instances)"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_read_latency_high" {
  alarm_name          = "emr-${var.env}-rds-read-latency-high"
  alarm_description   = "RDS read latency > 20ms"
  namespace           = "AWS/RDS"
  metric_name         = "ReadLatency"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 0.02 # 20ms in seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_write_latency_high" {
  alarm_name          = "emr-${var.env}-rds-write-latency-high"
  alarm_description   = "RDS write latency > 20ms"
  namespace           = "AWS/RDS"
  metric_name         = "WriteLatency"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 0.02 # 20ms in seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# API Gateway Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  alarm_name          = "emr-${var.env}-apigw-5xx"
  alarm_description   = "API Gateway 5xx errors > 5 in 5 minutes"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.critical.arn]
  ok_actions          = [aws_sns_topic.critical.arn]

  dimensions = {
    ApiName = var.api_gateway_name
    Stage   = var.api_gateway_stage
  }
}

resource "aws_cloudwatch_metric_alarm" "apigw_4xx" {
  alarm_name          = "emr-${var.env}-apigw-4xx-spike"
  alarm_description   = "API Gateway 4xx errors > 50 in 5 minutes"
  namespace           = "AWS/ApiGateway"
  metric_name         = "4XXError"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    ApiName = var.api_gateway_name
    Stage   = var.api_gateway_stage
  }
}

resource "aws_cloudwatch_metric_alarm" "apigw_latency" {
  alarm_name          = "emr-${var.env}-apigw-latency-high"
  alarm_description   = "API Gateway p95 latency > 3 seconds"
  namespace           = "AWS/ApiGateway"
  metric_name         = "Latency"
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 2
  threshold           = 3000 # milliseconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  dimensions = {
    ApiName = var.api_gateway_name
    Stage   = var.api_gateway_stage
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# CloudFront Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  alarm_name          = "emr-${var.env}-cloudfront-5xx"
  alarm_description   = "CloudFront 5xx error rate > 5%"
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]

  # CloudFront metrics are only available in us-east-1
  provider = aws

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# NLB Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_targets" {
  alarm_name          = "emr-${var.env}-nlb-unhealthy-targets"
  alarm_description   = "NLB has unhealthy targets"
  namespace           = "AWS/NetworkELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.critical.arn]
  ok_actions          = [aws_sns_topic.critical.arn]

  dimensions = {
    LoadBalancer = var.nlb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Log Metric Filters — Application-Level Alarms
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "emr-${var.env}-app-errors"
  log_group_name = var.ecs_log_group_name
  pattern        = "ERROR"

  metric_transformation {
    name      = "AppErrorCount"
    namespace = "EMR/${var.env}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "emr-${var.env}-app-error-spike"
  alarm_description   = "Application ERROR log count > 10 in 5 minutes"
  namespace           = "EMR/${var.env}"
  metric_name         = "AppErrorCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.warning.arn]
}

resource "aws_cloudwatch_log_metric_filter" "oom_errors" {
  name           = "emr-${var.env}-oom-errors"
  log_group_name = var.ecs_log_group_name
  pattern        = "OutOfMemoryError"

  metric_transformation {
    name      = "OOMErrorCount"
    namespace = "EMR/${var.env}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "oom_errors" {
  alarm_name          = "emr-${var.env}-oom-error"
  alarm_description   = "OutOfMemoryError detected in application logs"
  namespace           = "EMR/${var.env}"
  metric_name         = "OOMErrorCount"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.critical.arn]
  ok_actions          = [aws_sns_topic.critical.arn]
}

resource "aws_cloudwatch_log_metric_filter" "db_connection_errors" {
  name           = "emr-${var.env}-db-connection-errors"
  log_group_name = var.ecs_log_group_name
  pattern        = "?\"Connection refused\" ?\"too many connections\" ?\"Unable to acquire JDBC Connection\""

  metric_transformation {
    name      = "DBConnectionErrorCount"
    namespace = "EMR/${var.env}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "db_connection_errors" {
  alarm_name          = "emr-${var.env}-db-connection-error"
  alarm_description   = "Database connection errors detected in application logs"
  namespace           = "EMR/${var.env}"
  metric_name         = "DBConnectionErrorCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.critical.arn]
  ok_actions          = [aws_sns_topic.critical.arn]
}

# ─────────────────────────────────────────────────────────────────────────────
# Dashboard
# ─────────────────────────────────────────────────────────────────────────────

data "aws_region" "current" {}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "emr-${var.env}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU & Memory"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { stat = "Average" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS Running Tasks"
          region = data.aws_region.current.id
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS CPU & Connections"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average", yAxis = "right" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS Latency"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average" }],
            ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway Errors"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/ApiGateway", "5XXError", "ApiName", var.api_gateway_name, "Stage", var.api_gateway_stage, { stat = "Sum" }],
            ["AWS/ApiGateway", "4XXError", "ApiName", var.api_gateway_name, "Stage", var.api_gateway_stage, { stat = "Sum" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway Latency (p95)"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", var.api_gateway_name, "Stage", var.api_gateway_stage, { stat = "p95" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "RDS Free Storage (bytes)"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "NLB Healthy/Unhealthy Targets"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/NetworkELB", "HealthyHostCount", "LoadBalancer", var.nlb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average" }],
            ["AWS/NetworkELB", "UnHealthyHostCount", "LoadBalancer", var.nlb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      }
    ]
  })
}

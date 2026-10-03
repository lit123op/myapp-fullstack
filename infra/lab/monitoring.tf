resource "aws_sns_topic" "lab_alerts" {
  name = "${local.name}-alerts"

  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.lab_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_db_event_subscription" "lab" {
  name             = "${local.name}-db-events"
  sns_topic        = aws_sns_topic.lab_alerts.arn
  source_type      = "db-instance"
  source_ids       = concat([aws_db_instance.primary.identifier], var.enable_read_replica ? [aws_db_instance.read_replica[0].identifier] : [])
  event_categories = ["availability", "failure", "failover", "notification"]
  enabled          = true

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name}-rds-primary-cpu"
  alarm_description   = "Lab primary PostgreSQL CPU high."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.primary.identifier }
  alarm_actions       = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data  = "notBreaching"
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name}-rds-primary-free-storage"
  alarm_description   = "Lab primary has less than 5 GiB free storage."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5368709120
  comparison_operator = "LessThanOrEqualToThreshold"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.primary.identifier }
  alarm_actions       = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data  = "notBreaching"
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.name}-rds-primary-connections"
  alarm_description   = "Lab primary has an unexpectedly high connection count."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 50
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.primary.identifier }
  alarm_actions       = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data  = "notBreaching"
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_replica_lag" {
  count = var.enable_read_replica ? 1 : 0

  alarm_name          = "${local.name}-rds-replica-lag"
  alarm_description   = "Async read replica lag is at least 60 seconds."
  namespace           = "AWS/RDS"
  metric_name         = "ReplicaLag"
  statistic           = "Maximum"
  unit                = "Seconds"
  period              = 60
  evaluation_periods  = 2
  threshold           = 60
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.read_replica[0].identifier }
  alarm_actions       = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data  = "notBreaching"
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_frontend_cpu" {
  alarm_name          = "${local.name}-ecs-frontend-cpu"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    ClusterName = aws_ecs_cluster.lab.name
    ServiceName = aws_ecs_service.frontend.name
  }
  alarm_actions      = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_frontend_memory" {
  alarm_name          = "${local.name}-ecs-frontend-memory"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    ClusterName = aws_ecs_cluster.lab.name
    ServiceName = aws_ecs_service.frontend.name
  }
  alarm_actions      = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_api_cpu" {
  alarm_name          = "${local.name}-ecs-api-cpu"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    ClusterName = aws_ecs_cluster.lab.name
    ServiceName = aws_ecs_service.api.name
  }
  alarm_actions      = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_api_memory" {
  alarm_name          = "${local.name}-ecs-api-memory"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    ClusterName = aws_ecs_cluster.lab.name
    ServiceName = aws_ecs_service.api.name
  }
  alarm_actions      = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

locals {
  alb_target_groups = {
    frontend = aws_lb_target_group.frontend.arn_suffix
    api      = aws_lb_target_group.api.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  for_each = local.alb_target_groups

  alarm_name          = "${local.name}-alb-${each.key}-unhealthy-hosts"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    LoadBalancer = aws_lb.lab.arn_suffix
    TargetGroup  = each.value
  }
  alarm_actions      = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-elb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { LoadBalancer = aws_lb.lab.arn_suffix }
  alarm_actions       = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data  = "notBreaching"
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  for_each = local.alb_target_groups

  alarm_name          = "${local.name}-alb-${each.key}-target-latency"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 2
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    LoadBalancer = aws_lb.lab.arn_suffix
    TargetGroup  = each.value
  }
  alarm_actions      = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

resource "aws_cloudwatch_dashboard" "lab" {
  dashboard_name = "${local.name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "RDS primary CPU and free storage"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.primary.identifier],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.primary.identifier],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS replica lag"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = var.enable_read_replica ? [["AWS/RDS", "ReplicaLag", "DBInstanceIdentifier", aws_db_instance.read_replica[0].identifier]] : []
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "ALB target latency and 5xx by target group"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.lab.arn_suffix, "TargetGroup", local.alb_target_groups.frontend, { stat = "p95", label = "Frontend latency", yAxis = "left" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.lab.arn_suffix, "TargetGroup", local.alb_target_groups.api, { stat = "p95", label = "API latency", yAxis = "left" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.lab.arn_suffix, "TargetGroup", local.alb_target_groups.frontend, { stat = "Sum", label = "Frontend 5xx", yAxis = "right" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.lab.arn_suffix, "TargetGroup", local.alb_target_groups.api, { stat = "Sum", label = "API 5xx", yAxis = "right" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.lab.arn_suffix, { stat = "Sum", yAxis = "right" }],
          ]
        }
      },
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  for_each = local.alb_target_groups

  alarm_name          = "${local.name}-alb-${each.key}-target-5xx"
  alarm_description   = "One or more lab application targets returned HTTP 5xx."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    LoadBalancer = aws_lb.lab.arn_suffix
    TargetGroup  = each.value
  }
  alarm_actions      = [aws_sns_topic.lab_alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = local.tags
}
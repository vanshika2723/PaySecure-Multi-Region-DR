
# ---------------------------------------------------------
# PaySecure DR CloudWatch Alarms
# ---------------------------------------------------------

resource "aws_cloudwatch_log_group" "dr" {
  provider = aws.primary

  name              = "/paysecure/dr"
  retention_in_days = 30

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-dr-logs"
    Purpose = "DR monitoring"
  })
}

# ---------------------------------------------------------
# Payment API P99 Latency
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "payment_api_latency" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-payment-api-p99-latency"
  alarm_description   = "Payment API P99 latency exceeded 300ms."
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 5
  datapoints_to_alarm = 5

  metric_name = "TransactionP99Latency"
  namespace   = "Custom/PaySecure/Payments"

  period    = 60
  statistic = "Maximum"

  threshold = 300

  treat_missing_data = "notBreaching"

  tags = merge(local.common_tags, {
    Severity = "P2"
    Service  = "PaymentAPI"
  })
}

# ---------------------------------------------------------
# Payment Success Rate
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "payment_success_rate" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-payment-success-rate"
  alarm_description   = "Payment API success rate dropped below 99.5%."
  comparison_operator = "LessThanThreshold"

  evaluation_periods  = 2
  datapoints_to_alarm = 2

  metric_name = "PaymentSuccessRate"
  namespace   = "Custom/PaySecure/Payments"

  period    = 60
  statistic = "Minimum"

  threshold = 99.5

  treat_missing_data = "breaching"

  tags = merge(local.common_tags, {
    Severity = "P1"
    Service  = "PaymentAPI"
  })
}

# ---------------------------------------------------------
# Aurora Global Database Replication Lag
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "aurora_replication_lag" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-aurora-replication-lag"
  alarm_description   = "Aurora Global Database replication lag exceeded 500ms."
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods  = 2
  datapoints_to_alarm = 2

  metric_name = "AuroraGlobalDBReplicationLag"
  namespace   = "AWS/RDS"

  period    = 60
  statistic = "Maximum"

  threshold = 500

  treat_missing_data = "breaching"

  tags = merge(local.common_tags, {
    Severity = "P1"
    Service  = "Aurora"
  })
}

# ---------------------------------------------------------
# DynamoDB Replication Latency
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "dynamodb_replication_latency" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-dynamodb-replication-latency"
  alarm_description   = "DynamoDB Global Table replication latency exceeded 1000ms."
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods  = 3
  datapoints_to_alarm = 3

  metric_name = "ReplicationLatency"
  namespace   = "AWS/DynamoDB"

  period    = 60
  statistic = "Maximum"

  threshold = 1000

  treat_missing_data = "breaching"

  tags = merge(local.common_tags, {
    Severity = "P1"
    Service  = "DynamoDB"
  })
}

# ---------------------------------------------------------
# Redis Replication Lag
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "redis_replication_lag" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-redis-replication-lag"
  alarm_description   = "Redis cross-region replication lag exceeded 2000ms."
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods  = 3
  datapoints_to_alarm = 3

  metric_name = "GlobalDatastoreReplicationLag"
  namespace   = "AWS/ElastiCache"

  period    = 60
  statistic = "Maximum"

  threshold = 2000

  treat_missing_data = "breaching"

  tags = merge(local.common_tags, {
    Severity = "P2"
    Service  = "Redis"
  })
}

# ---------------------------------------------------------
# MSK Replication Lag
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "msk_replication_lag" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-msk-replication-lag"
  alarm_description   = "MSK replication lag exceeded 10000 messages."
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods  = 5
  datapoints_to_alarm = 5

  metric_name = "ReplicationLagMessages"
  namespace   = "Custom/PaySecure/MSK"

  period    = 60
  statistic = "Maximum"

  threshold = 10000

  treat_missing_data = "breaching"

  tags = merge(local.common_tags, {
    Severity = "P2"
    Service  = "MSK"
  })
}

# ---------------------------------------------------------
# DR Composite Health
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "dr_composite_health" {
  provider = aws.primary

  alarm_name          = "${var.project_name}-dr-composite-health"
  alarm_description   = "Critical DR composite health check failed."
  comparison_operator = "LessThanThreshold"

  evaluation_periods  = 1
  datapoints_to_alarm = 1

  metric_name = "CompositeHealth"
  namespace   = "Custom/PaySecure/DR"

  period    = 60
  statistic = "Minimum"

  threshold = 1

  treat_missing_data = "breaching"

  tags = merge(local.common_tags, {
    Severity = "P1"
    Service  = "DR"
  })
}

# ---------------------------------------------------------
# Outputs
# ---------------------------------------------------------

output "payment_api_latency_alarm_arn" {
  description = "Payment API latency alarm ARN."
  value       = aws_cloudwatch_metric_alarm.payment_api_latency.arn
}

output "payment_success_rate_alarm_arn" {
  description = "Payment success rate alarm ARN."
  value       = aws_cloudwatch_metric_alarm.payment_success_rate.arn
}

output "aurora_replication_alarm_arn" {
  description = "Aurora replication lag alarm ARN."
  value       = aws_cloudwatch_metric_alarm.aurora_replication_lag.arn
}

output "dynamodb_replication_alarm_arn" {
  description = "DynamoDB replication latency alarm ARN."
  value       = aws_cloudwatch_metric_alarm.dynamodb_replication_latency.arn
}

output "redis_replication_alarm_arn" {
  description = "Redis replication lag alarm ARN."
  value       = aws_cloudwatch_metric_alarm.redis_replication_lag.arn
}

output "msk_replication_alarm_arn" {
  description = "MSK replication lag alarm ARN."
  value       = aws_cloudwatch_metric_alarm.msk_replication_lag.arn
}

output "dr_composite_health_alarm_arn" {
  description = "DR composite health alarm ARN."
  value       = aws_cloudwatch_metric_alarm.dr_composite_health.arn
}


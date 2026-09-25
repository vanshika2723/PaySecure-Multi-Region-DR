
resource "aws_route53_health_check" "primary" {
  count = var.enable_health_checks ? 1 : 0

  fqdn              = var.primary_health_check_fqdn
  port              = var.health_check_port
  type              = var.health_check_type
  resource_path     = var.health_check_path
  request_interval  = var.health_check_interval
  failure_threshold = var.failure_threshold

  tags = merge(
    var.common_tags,
    {
      Name   = "${var.zone_name}-primary-health-check"
      Region = var.primary_region
    }
  )
}

resource "aws_route53_health_check" "dr" {
  count = var.enable_health_checks ? 1 : 0

  fqdn              = var.dr_health_check_fqdn
  port              = var.health_check_port
  type              = var.health_check_type
  resource_path     = var.health_check_path
  request_interval  = var.health_check_interval
  failure_threshold = var.failure_threshold

  tags = merge(
    var.common_tags,
    {
      Name   = "${var.zone_name}-dr-health-check"
      Region = var.dr_region
    }
  )
}

resource "aws_route53_record" "primary" {
  zone_id = var.hosted_zone_id
  name    = var.record_name
  type    = var.record_type

  set_identifier = "primary-${var.primary_region}"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = var.primary_endpoint
    zone_id                = var.primary_alias_zone_id
    evaluate_target_health = true
  }

  health_check_id = var.enable_health_checks ? aws_route53_health_check.primary[0].id : null
}

resource "aws_route53_record" "dr" {
  zone_id = var.hosted_zone_id
  name    = var.record_name
  type    = var.record_type

  set_identifier = "dr-${var.dr_region}"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.dr_endpoint
    zone_id                = var.dr_alias_zone_id
    evaluate_target_health = true
  }

  health_check_id = var.enable_health_checks ? aws_route53_health_check.dr[0].id : null
}

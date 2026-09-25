output "primary_health_check_id" {
  description = "Route 53 primary health check ID."
  value = var.enable_health_checks
    ? aws_route53_health_check.primary[0].id
    : null
}

output "dr_health_check_id" {
  description = "Route 53 DR health check ID."
  value = var.enable_health_checks
    ? aws_route53_health_check.dr[0].id
    : null
}

output "primary_record_fqdn" {
  description = "Primary failover record FQDN."
  value       = aws_route53_record.primary.fqdn
}

output "dr_record_fqdn" {
  description = "DR failover record FQDN."
  value       = aws_route53_record.dr.fqdn
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID."
  value       = var.hosted_zone_id
}


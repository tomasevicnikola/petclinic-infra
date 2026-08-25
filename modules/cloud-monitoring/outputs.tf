output "dashboard_id" {
  description = "Resource name of the Cloud Monitoring dashboard."
  value       = google_monitoring_dashboard.this.id
}

output "alert_policy_names" {
  description = "Alert policies created here, for cross-checking against the Prometheus rules that cover the same conditions."
  value = [
    google_monitoring_alert_policy.high_cpu.display_name,
    google_monitoring_alert_policy.application_downtime.display_name,
    google_monitoring_alert_policy.uptime.display_name,
  ]
}

output "uptime_check_id" {
  description = "Uptime check watching the load balancer from outside the VPC."
  value       = google_monitoring_uptime_check_config.lb.uptime_check_id
}

output "notification_channel" {
  description = "Notification channel id, or null when no address was supplied."
  value       = one(google_monitoring_notification_channel.email[*].id)
}

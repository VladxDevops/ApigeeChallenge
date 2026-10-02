output "dashboard_id" {
  description = "The resource ID of the Cloud Monitoring Latency & Observability Dashboard."
  value       = google_monitoring_dashboard.api_latency_dashboard.id
}

output "alert_policy_high_latency_id" {
  description = "The resource ID of the high backend latency alert policy."
  value       = var.enable_alerting && length(google_monitoring_alert_policy.high_backend_latency) > 0 ? google_monitoring_alert_policy.high_backend_latency[0].id : null
}

output "alert_policy_high_5xx_error_rate_id" {
  description = "The resource ID of the high 5xx error rate alert policy."
  value       = var.enable_alerting && length(google_monitoring_alert_policy.high_5xx_error_rate) > 0 ? google_monitoring_alert_policy.high_5xx_error_rate[0].id : null
}

output "alert_policy_cloud_run_memory_id" {
  description = "The resource ID of the Cloud Run container memory alert policy."
  value       = var.enable_alerting && length(google_monitoring_alert_policy.cloud_run_memory_high) > 0 ? google_monitoring_alert_policy.cloud_run_memory_high[0].id : null
}

output "alert_policy_vpn_tunnel_down_id" {
  description = "The resource ID of the Cloud VPN tunnel down alert policy."
  value       = var.enable_alerting && length(google_monitoring_alert_policy.vpn_tunnel_down) > 0 ? google_monitoring_alert_policy.vpn_tunnel_down[0].id : null
}

output "notification_channel_id" {
  description = "The resource ID of the email notification channel if configured."
  value       = var.enable_alerting && var.notification_email != "" && length(google_monitoring_notification_channel.email) > 0 ? google_monitoring_notification_channel.email[0].id : null
}

output "cloud_armor_denied_metric_name" {
  description = "The metric descriptor name of the Cloud Armor denied requests log-based metric."
  value       = google_logging_metric.cloud_armor_denied_requests.name
}

output "apigee_target_errors_metric_name" {
  description = "The metric descriptor name of the Apigee target 5xx errors log-based metric."
  value       = google_logging_metric.apigee_target_errors.name
}

output "peak_hour_high_latency_metric_name" {
  description = "The metric descriptor name of the peak hour high latency log-based metric."
  value       = google_logging_metric.peak_hour_high_latency_requests.name
}

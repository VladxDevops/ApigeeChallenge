# Log-Based Metrics for Apigee Challenge Observability
#
# These metrics extract structured signals directly from Cloud Logging
# without requiring third-party agents or external infrastructure.
#
# Metrics created:
# 1. cloud_armor_denied_requests: Tracks requests blocked by Cloud Armor WAF.
# 2. apigee_target_errors: Tracks HTTP 5xx responses returned by backend targets to Apigee.
# 3. peak_hour_high_latency_requests: Tracks requests with latency > 2000ms at the perimeter.

resource "google_logging_metric" "cloud_armor_denied_requests" {
  project = var.compute_project_id
  name    = "cloud_armor_denied_requests"
  filter  = "resource.type=\"http_load_balancer\" AND jsonPayload.enforcedSecurityPolicy.outcome=\"DENY\""

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = "Cloud Armor Denied Requests"
  }

  description = "Counts perimeter requests blocked or denied by Cloud Armor security policies."
}

resource "google_logging_metric" "apigee_target_errors" {
  project = var.compute_project_id
  name    = "apigee_target_errors"
  filter  = "resource.type=\"apigee_proxy\" AND jsonPayload.target_response_code >= 500"

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = "Apigee Target 5xx Errors"
  }

  description = "Counts 5xx errors returned by backend target services (Cloud Run or On-Prem) to Apigee."
}

resource "google_logging_metric" "peak_hour_high_latency_requests" {
  project = var.compute_project_id
  name    = "peak_hour_high_latency_requests"
  filter  = "resource.type=\"http_load_balancer\" AND httpRequest.latency > \"2s\""

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    display_name = "Edge High Latency Requests (>2s)"
  }

  description = "Counts requests where total perimeter round-trip latency exceeds 2 seconds during peak hours."
}

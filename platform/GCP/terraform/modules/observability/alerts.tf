# Cloud Monitoring Alert Policies for Apigee Challenge
#
# These alert policies detect anomalous conditions across the latency and availability path:
# 1. High Backend Latency (> threshold ms): Detects peak-hour latency spikes.
# 2. High 5xx Error Rate: Detects failing backend targets or connectivity breaks.
# 3. Cloud Run High Memory Utilization (> 85%): Detects backend memory saturation.
# 4. Cloud VPN Tunnel Down: Detects hybrid connectivity interruption to on-premises core.

# Optional Email Notification Channel
resource "google_monitoring_notification_channel" "email" {
  count        = var.enable_alerting && var.notification_email != "" ? 1 : 0
  project      = var.compute_project_id
  display_name = "Apigee DevOps Notification Channel"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }

  user_labels = var.labels
}

# Alert Policy 1: High Backend Latency (Peak-Hour Bottleneck Detection)
resource "google_monitoring_alert_policy" "high_backend_latency" {
  count        = var.enable_alerting ? 1 : 0
  project      = var.compute_project_id
  display_name = "Apigee - High Backend Latency (> ${var.latency_threshold_ms}ms)"
  combiner     = "OR"

  conditions {
    display_name = "Backend Latency p95 > ${var.latency_threshold_ms}ms"
    condition_threshold {
      filter          = "resource.type = \"http_load_balancer\" AND metric.type = \"loadbalancing.googleapis.com/https/backend_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_threshold_ms

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "### Peak-Hour High Latency Incident\n\n**Observed Condition:** 95th percentile backend latency on the Application Load Balancer exceeds ${var.latency_threshold_ms}ms over a 5-minute alignment window.\n\n**Triage Procedure (Oral Defense Aligned):**\n1. Check the Apigee End-to-End Latency Dashboard.\n2. Compare **Apigee Proxy Response Time** (gateway processing) vs **Apigee Target Response Time** (backend wait).\n3. If Target Response Time is elevated, determine the backend target:\n   - **Cloud Run target:** Review container CPU/memory saturation, concurrency settings, and active instance counts.\n   - **On-premises core target:** Check Cloud VPN throughput, on-premises Java application server thread pool usage, and database query/lock latency.\n4. **Oral Defense Takeaway:** The Load Balancer terminates perimeter TLS; high latency is caused downstream at the backend or database layer, not at the ingress proxy."
    mime_type = "text/markdown"
  }

  notification_channels = var.notification_email != "" ? [google_monitoring_notification_channel.email[0].name] : []
  user_labels           = var.labels
}

# Alert Policy 2: High 5xx Error Spike at Perimeter
resource "google_monitoring_alert_policy" "high_5xx_error_rate" {
  count        = var.enable_alerting ? 1 : 0
  project      = var.compute_project_id
  display_name = "Apigee - High 5xx Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "HTTP 5xx Error Spike (>10 req/min)"
    condition_threshold {
      filter          = "resource.type = \"http_load_balancer\" AND metric.type = \"loadbalancing.googleapis.com/https/request_count\" AND metric.labels.response_code_class = \"500\""
      duration        = "180s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "### High 5xx Error Rate Detected\n\nRequests returning HTTP 5xx have spiked at the external load balancer. Check Apigee proxy execution logs and backend target health to isolate failing target servers or upstream connectivity issues."
    mime_type = "text/markdown"
  }

  notification_channels = var.notification_email != "" ? [google_monitoring_notification_channel.email[0].name] : []
  user_labels           = var.labels
}

# Alert Policy 3: Cloud Run Container Memory Saturation
resource "google_monitoring_alert_policy" "cloud_run_memory_high" {
  count        = var.enable_alerting ? 1 : 0
  project      = var.compute_project_id
  display_name = "Cloud Run - High Container Memory (>85%)"
  combiner     = "OR"

  conditions {
    display_name = "Container Memory Utilization > 85%"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/container/memory/utilizations\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "### Cloud Run Container Memory Saturation\n\nMemory utilization on Cloud Run container instances has exceeded 85%. Review application heap utilization and container resource allocation in Cloud Run configuration."
    mime_type = "text/markdown"
  }

  notification_channels = var.notification_email != "" ? [google_monitoring_notification_channel.email[0].name] : []
  user_labels           = var.labels
}

# Alert Policy 4: Hybrid Connectivity - Cloud VPN Tunnel Down
resource "google_monitoring_alert_policy" "vpn_tunnel_down" {
  count        = var.enable_alerting ? 1 : 0
  project      = var.compute_project_id
  display_name = "Hybrid Connectivity - Cloud VPN Tunnel Down"
  combiner     = "OR"

  conditions {
    display_name = "VPN Tunnel Established < 1"
    condition_threshold {
      filter          = "resource.type = \"vpn_gateway\" AND metric.type = \"vpn.googleapis.com/network/tunnel_established\""
      duration        = "120s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "### Critical: Cloud VPN Tunnel to On-Premises Core Down\n\nThe Cloud VPN tunnel connecting Hub VPC to the on-premises environment has transitioned to a down state. Connectivity to the on-premises Java application server and relational database is interrupted."
    mime_type = "text/markdown"
  }

  notification_channels = var.notification_email != "" ? [google_monitoring_notification_channel.email[0].name] : []
  user_labels           = var.labels
}

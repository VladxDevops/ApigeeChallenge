# API Monitoring and a Cloud Monitoring dashboard for hello-world-proxy.
#
# Apigee API Monitoring for Apigee X is Cloud Monitoring. These resources use the
# published descriptors (docs.cloud.google.com/monitoring/api/metrics_gcp, apigee):
#   resource.type = "apigee.googleapis.com/Proxy"
#     apigee.googleapis.com/proxy/request_count
#     apigee.googleapis.com/proxy/response_count
#     apigee.googleapis.com/proxy/latencies          (proxy overhead + target time)
#   resource.type = "apigee.googleapis.com/Target"
#     apigee.googleapis.com/target/latencies         (target time only)
#     apigee.googleapis.com/target/response_count
# proxy_name and env are resource labels on both monitored resources.
#
# The five-hop dashboard in dashboards.tf stays as the architecture view. It still
# filters apigee_proxy / proxy/response_time, which are not the published descriptors.

locals {
  hello_world_proxy_resource_filter = join(" AND ", [
    "resource.labels.proxy_name=\"${var.apigee_proxy_name}\"",
    "resource.labels.env=\"${var.apigee_environment_name}\"",
  ])
}

resource "google_monitoring_dashboard" "hello_world_proxy" {
  project = var.compute_project_id

  dashboard_json = jsonencode({
    displayName = "${var.apigee_proxy_name} API Monitoring"
    gridLayout = {
      columns = "2"
      widgets = [
        {
          title = "hello-world-proxy API Monitoring"
          text = {
            content = "### ${var.apigee_proxy_name}\n\nEnvironment `${var.apigee_environment_name}`. Base path `/hello`. Smoke-test proxy on the Apigee runtime.\n\n**Proxy latency** (`apigee.googleapis.com/proxy/latencies`) is the time from when Apigee accepts the request until it sends the response. That includes gateway time and target time.\n\n**Target latency** (`apigee.googleapis.com/target/latencies`) is only the wait for the target. A high target series with a similar proxy series means the backend, not the proxy policies, is the delay.\n\nCharts are limited to `resource.labels.proxy_name=\"${var.apigee_proxy_name}\"` and `resource.labels.env=\"${var.apigee_environment_name}\"`."
            format  = "MARKDOWN"
          }
        },
        {
          title = "Proxy request rate"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/proxy/request_count\" AND resource.type=\"apigee.googleapis.com/Proxy\" AND ${local.hello_world_proxy_resource_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.method"]
                    }
                  }
                }
                plotType   = "STACKED_BAR"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Requests / sec"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Proxy responses by HTTP status"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/proxy/response_count\" AND resource.type=\"apigee.googleapis.com/Proxy\" AND ${local.hello_world_proxy_resource_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.response_code"]
                    }
                  }
                }
                plotType   = "STACKED_BAR"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Responses / sec"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Proxy latency p95 (gateway + target)"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/proxy/latencies\" AND resource.type=\"apigee.googleapis.com/Proxy\" AND ${local.hello_world_proxy_resource_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Latency (ms)"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Target latency p95 (backend wait only)"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/target/latencies\" AND resource.type=\"apigee.googleapis.com/Target\" AND ${local.hello_world_proxy_resource_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Latency (ms)"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Target responses by HTTP status"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/target/response_count\" AND resource.type=\"apigee.googleapis.com/Target\" AND ${local.hello_world_proxy_resource_filter}"
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.response_code"]
                    }
                  }
                }
                plotType   = "STACKED_BAR"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Responses / sec"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Proxy faults by source"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/proxy/response_count\" AND resource.type=\"apigee.googleapis.com/Proxy\" AND ${local.hello_world_proxy_resource_filter} AND metric.labels.fault_source!=\"\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.fault_source"]
                    }
                  }
                }
                plotType   = "STACKED_BAR"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Faults / sec"
              scale = "LINEAR"
            }
          }
        }
      ]
    }
  })
}

# API Monitoring alerts. Same gate as the other policies in alerts.tf: Cloud
# Monitoring rejects an AlertPolicy when the metric descriptor is not registered
# in the project yet. The dashboard above is created regardless.
resource "google_monitoring_alert_policy" "hello_world_proxy_latency" {
  count        = var.enable_alerting && var.create_alerts_when_metrics_ready ? 1 : 0
  project      = var.compute_project_id
  display_name = "${var.apigee_proxy_name} - Proxy latency p95 > ${var.latency_threshold_ms}ms"
  combiner     = "OR"

  conditions {
    display_name = "${var.apigee_proxy_name} proxy latency p95 > ${var.latency_threshold_ms}ms"
    condition_threshold {
      filter          = "metric.type=\"apigee.googleapis.com/proxy/latencies\" AND resource.type=\"apigee.googleapis.com/Proxy\" AND ${local.hello_world_proxy_resource_filter}"
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
    content   = "### ${var.apigee_proxy_name} latency\n\n95th percentile proxy latency on environment `${var.apigee_environment_name}` exceeded ${var.latency_threshold_ms}ms for 5 minutes.\n\nOpen the `${var.apigee_proxy_name} API Monitoring` dashboard and compare **Proxy latency p95** with **Target latency p95**. If the target series is also high, the wait is in the backend. If only the proxy series is high, the time is inside the proxy."
    mime_type = "text/markdown"
  }

  notification_channels = var.notification_email != "" ? [google_monitoring_notification_channel.email[0].name] : []
  user_labels           = var.labels
}

resource "google_monitoring_alert_policy" "hello_world_proxy_5xx" {
  count        = var.enable_alerting && var.create_alerts_when_metrics_ready ? 1 : 0
  project      = var.compute_project_id
  display_name = "${var.apigee_proxy_name} - HTTP 5xx response rate"
  combiner     = "OR"

  conditions {
    display_name = "${var.apigee_proxy_name} HTTP 5xx > 0.1 responses/sec"
    condition_threshold {
      filter          = "metric.type=\"apigee.googleapis.com/proxy/response_count\" AND resource.type=\"apigee.googleapis.com/Proxy\" AND ${local.hello_world_proxy_resource_filter} AND metric.labels.response_code=monitoring.regex.full_match(\"5..\")"
      duration        = "180s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.1

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["metric.label.response_code"]
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "### ${var.apigee_proxy_name} HTTP 5xx\n\nThe proxy returned HTTP 5xx faster than 0.1 responses/sec for 3 minutes. Check `fault_source` on the API Monitoring dashboard: `target` is the backend, `apigee` is the runtime, `policy` is a policy fault."
    mime_type = "text/markdown"
  }

  notification_channels = var.notification_email != "" ? [google_monitoring_notification_channel.email[0].name] : []
  user_labels           = var.labels
}

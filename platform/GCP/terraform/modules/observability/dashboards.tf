# Cloud Monitoring Dashboard for Multi-Hop Latency & Telemetry
#
# Oral Defense Alignment:
# The challenge diagram explicitly highlights: "Servidor Java + Base de datos relacional · Latencia alta en hora pico".
# A Load Balancer only terminates TLS and manages perimeter routing; it does NOT optimize downstream SQL queries.
# This dashboard provides continuous telemetry across all 5 architectural hops to isolate bottlenecks:
#   Hop 1: External Application Load Balancer & Cloud Armor (Edge & WAF)
#   Hop 2: Apigee Non-VPC-Peering Managed Runtime (Gateway Overhead vs Target Latency)
#   Hop 3: Private Service Connect & Cloud Run Backend
#   Hop 4: Central Hub VPC & HA Cloud VPN (Hybrid Network Path)
#   Hop 5: On-Premises Core (Java App + Relational Database)

resource "google_monitoring_dashboard" "api_latency_dashboard" {
  project = var.compute_project_id

  dashboard_json = jsonencode({
    displayName = var.dashboard_name
    gridLayout = {
      columns = "2"
      widgets = [
        # Widget 1: Architecture & Latency Correlation Reference (Markdown)
        {
          title = "End-to-End Latency Chain & Oral Exam Diagnostic Guide"
          text = {
            content = "### Multi-Hop Request & Latency Trace Path\n\n1. **Hop 1: Edge & WAF** — Regional External ALB (`10.80.0.64/26` Proxy Subnet) + Cloud Armor WAF.\n2. **Hop 2: Managed API Runtime** — Apigee (Non-VPC-Peering) entered via Northbound PSC.\n3. **Hop 3: Transition to Internal** — Southbound PSC Endpoint Attachment → Producer Service Attachment (`10.80.0.16/29` PSC NAT Subnet).\n4. **Hop 4: Hybrid Connectivity** — Hub VPC (`10.20.0.0/16`) via HA Cloud VPN to On-Premises.\n5. **Hop 5: On-Premises Core** — Java Application Server & Relational Database (*high peak-hour latency*).\n\n> **Key Defense Principle:** The Load Balancer terminates edge TLS and directs traffic; it does **not** optimize downstream database locks or connection pool exhaustion. Use the charts below to pinpoint which hop is responsible for latency spikes."
            format  = "MARKDOWN"
          }
        },

        # Widget 2: Hop 1 ALB Request Volume & Response Code Breakdown
        {
          title = "Hop 1: External ALB - Request Volume by HTTP Status"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type = \"loadbalancing.googleapis.com/https/request_count\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.response_code_class"]
                    }
                  }
                }
                plotType   = "STACKED_BAR"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Requests / Sec"
              scale = "LINEAR"
            }
          }
        },

        # Widget 3: Hop 1 ALB Latency (Total Latency vs Backend Latency p95)
        {
          title = "Hop 1: External ALB Latency - Total vs Backend (p95)"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type = \"loadbalancing.googleapis.com/https/total_latencies\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type = \"loadbalancing.googleapis.com/https/backend_latencies\""
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

        # Widget 4: Hop 2 Apigee Runtime Latency (Proxy Processing vs Target Response Time)
        # Crucial to distinguish Apigee policy overhead from backend delay!
        {
          title = "Hop 2: Apigee Latency - Gateway Overhead vs Target Time (p95)"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/proxy/response_time\" resource.type=\"apigee_proxy\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/target/response_time\" resource.type=\"apigee_proxy\""
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
              label = "Response Time (ms)"
              scale = "LINEAR"
            }
          }
        },

        # Widget 5: Hop 2 Apigee Proxy Traffic & Error Rate
        {
          title = "Hop 2: Apigee Proxy Traffic & Error Count"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/proxy/request_count\" resource.type=\"apigee_proxy\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"apigee.googleapis.com/proxy/error_count\" resource.type=\"apigee_proxy\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Count / Sec"
              scale = "LINEAR"
            }
          }
        },

        # Widget 6: Hop 3 Cloud Run Backend Latency Percentiles (p50, p95, p99)
        {
          title = "Hop 3: Cloud Run Backend - Latency Percentiles (p50, p95, p99)"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_50"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_99"
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

        # Widget 7: Hop 3 Cloud Run Container Utilization
        {
          title = "Hop 3: Cloud Run Container CPU & Memory Utilization (p95)"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/container/cpu/utilizations\" resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/container/memory/utilizations\" resource.type=\"cloud_run_revision\""
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
              label = "Utilization Ratio (0.0 - 1.0)"
              scale = "LINEAR"
            }
          }
        },

        # Widget 8: Hop 4 Cloud VPN Tunnel Status & Packet Drops
        {
          title = "Hop 4: Cloud VPN to On-Premises - Tunnel Status & Packet Drops"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"vpn.googleapis.com/network/tunnel_established\" resource.type=\"vpn_gateway\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"vpn.googleapis.com/network/dropped_packets\" resource.type=\"vpn_gateway\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y2"
              }
            ]
            yAxis = {
              label = "Tunnel Status (1=Up, 0=Down)"
              scale = "LINEAR"
            }
          }
        },

        # Widget 9: Hop 4 Cloud VPN Network Throughput (Sent vs Received)
        {
          title = "Hop 4: Cloud VPN - Throughput to On-Premises (Bytes/Sec)"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"vpn.googleapis.com/network/sent_bytes_count\" resource.type=\"vpn_gateway\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"vpn.googleapis.com/network/received_bytes_count\" resource.type=\"vpn_gateway\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Bytes / Sec"
              scale = "LINEAR"
            }
          }
        },

        # Widget 10: Hop 1 Security - Cloud Armor WAF Denied Requests
        {
          title = "Hop 1 Security: Cloud Armor WAF Denied Requests"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"logging.googleapis.com/user/cloud_armor_denied_requests\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                    }
                  }
                }
                plotType   = "LINE"
                targetAxis = "Y1"
              }
            ]
            yAxis = {
              label = "Blocked Requests / Sec"
              scale = "LINEAR"
            }
          }
        }
      ]
    }
  })
}

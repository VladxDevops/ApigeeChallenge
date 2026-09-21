# Observability Terraform Module — Apigee Challenge

## Overview

This Terraform module implements the **end-to-end observability and latency diagnostic framework** for the Rocket Code Apigee Challenge architecture in `us-south1`.

A central focal point of the technical exercise and oral defense is the condition noted in the prompt diagram:
> *"Servidor Java + Base de datos relacional · Latencia alta en hora pico"* (On-premises Java server + relational database experiences high latency during peak hours).

### Oral Defense Rationale & Core Principle

1. **The Load Balancer does NOT resolve database bottlenecks**: A Regional External Application Load Balancer terminates TLS at the perimeter, performs HTTP routing, and enforces Cloud Armor WAF policies. It cannot optimize slow SQL queries, database lock contention, or exhausted connection pools.
2. **Observability must isolate where latency occurs**: Rather than guessing or assuming network transit delays, this module establishes continuous, multi-hop telemetry across all 5 architectural segments:
   - **Hop 1: Edge & WAF** (`loadbalancing.googleapis.com/https/backend_latencies`, `total_latencies`, Cloud Armor security logs).
   - **Hop 2: Managed API Runtime** (`apigee.googleapis.com/proxy/response_time` vs `target/response_time` to differentiate gateway policy overhead from backend wait time).
   - **Hop 3: Cloud Run Backend** (`run.googleapis.com/request_latencies` p50/p95/p99, container CPU/memory utilization).
   - **Hop 4: Central Hub VPC & Cloud VPN** (`vpn.googleapis.com/network/tunnel_established`, throughput, packet drops).
   - **Hop 5: On-Premises Core** (Isolated via Apigee target response times and VPN metrics).

---

## Resources Provisioned

### 1. Cloud Monitoring Dashboard (`google_monitoring_dashboard`)
A dedicated grid dashboard (`Apigee End-to-End Latency & Observability Dashboard`) containing 10 widgets:
- **Architecture & Latency Diagnostic Reference Guide** (Markdown reference).
- **Hop 1 External ALB Request Volume by Status Code** (2xx, 4xx, 5xx).
- **Hop 1 External ALB Latency** (Total round-trip vs Backend latency p95).
- **Hop 2 Apigee Runtime Latency** (Proxy policy overhead vs Target response time p95).
- **Hop 2 Apigee Proxy Traffic & Error Rate** (Requests vs Errors per second).
- **Hop 3 Cloud Run Backend Latency Percentiles** (p50, p95, p99).
- **Hop 3 Cloud Run Container Resource Saturation** (CPU & Memory utilization p95).
- **Hop 4 Cloud VPN Tunnel Health & Packet Drops** (Tunnel status & drop rate).
- **Hop 4 Cloud VPN Network Throughput** (Sent vs Received bytes per second).
- **Hop 1 Security: Cloud Armor WAF Denied Requests** (Log-based metric rate).

### 2. Log-Based Metrics (`google_logging_metric`)
- `cloud_armor_denied_requests`: Tracks perimeter requests blocked or denied by Cloud Armor security policies.
- `apigee_target_errors`: Tracks HTTP 5xx responses returned by downstream backend targets to Apigee.
- `peak_hour_high_latency_requests`: Tracks requests where round-trip latency exceeds 2 seconds.

### 3. Cloud Monitoring Alert Policies (`google_monitoring_alert_policy`)
- **High Backend Latency Alert**: Alerts when 95th percentile backend latency exceeds threshold (`var.latency_threshold_ms`, default `2000ms`) over 5 minutes. Includes markdown documentation detailing the triage runbook.
- **High 5xx Error Rate Alert**: Alerts when HTTP 5xx errors spike (> 10 req/min) at the perimeter load balancer.
- **Cloud Run Container Memory Saturation Alert**: Alerts when container memory utilization exceeds 85%.
- **Cloud VPN Tunnel Down Alert**: Critical alert triggered when the Cloud VPN tunnel to on-premises core transitions to a down state.
- **Notification Channel (`google_monitoring_notification_channel`)**: Optional email channel for team alerts.

---

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `compute_project_id` | `string` | *Required* | Compute project ID for the GCP project. |
| `compute_project_number` | `string` | `""` | Compute project number. |
| `compute_region` | `string` | `"us-south1"` | Compute region for resources. |
| `dashboard_name` | `string` | `"Apigee End-to-End Latency & Observability Dashboard"` | Display name for the dashboard. |
| `enable_alerting` | `bool` | `true` | Whether to provision alert policies. |
| `notification_email` | `string` | `""` | Optional email address for alerts. |
| `latency_threshold_ms` | `number` | `2000` | Backend latency threshold in ms (p95). |
| `error_rate_threshold_percent` | `number` | `5` | 5xx error rate threshold percentage. |
| `cloud_run_service_name` | `string` | `"api-backend-service"` | Cloud Run service name. |
| `vpn_gateway_name` | `string` | `"hub-to-onprem-vpn-gw"` | Cloud VPN gateway name. |
| `labels` | `map(string)` | `{ environment = "dev", managed-by = "terraform", domain = "observability" }` | Resource labels. |

---

## Outputs

| Name | Description |
|---|---|
| `dashboard_id` | Resource ID of the Cloud Monitoring Latency Dashboard. |
| `alert_policy_high_latency_id` | Resource ID of the high backend latency alert policy. |
| `alert_policy_high_5xx_error_rate_id` | Resource ID of the 5xx error rate alert policy. |
| `alert_policy_cloud_run_memory_id` | Resource ID of the Cloud Run container memory alert policy. |
| `alert_policy_vpn_tunnel_down_id` | Resource ID of the Cloud VPN tunnel down alert policy. |
| `notification_channel_id` | Resource ID of the email notification channel. |
| `cloud_armor_denied_metric_name` | Metric descriptor name for Cloud Armor blocked requests. |
| `apigee_target_errors_metric_name` | Metric descriptor name for Apigee target 5xx errors. |
| `peak_hour_high_latency_metric_name` | Metric descriptor name for peak-hour high latency requests. |

---

## Usage Example

```hcl
module "observability" {
  source = "./modules/observability"

  compute_project_id     = var.compute_project_id
  compute_project_number = var.compute_project_number
  compute_region         = var.compute_region

  dashboard_name       = "Apigee End-to-End Latency & Observability Dashboard"
  enable_alerting      = true
  latency_threshold_ms = 2000
  notification_email   = "devops-alerts@company.com"

  labels = {
    environment = "dev"
    managed-by  = "terraform"
    domain      = "observability"
  }
}
```

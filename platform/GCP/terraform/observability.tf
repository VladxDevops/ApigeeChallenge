# Observability Module for Rocket Code Apigee Challenge
# Provisions Cloud Monitoring Dashboard, Alert Policies, and Log-Based Metrics
# to trace and diagnose the multi-hop latency chain across all 5 architectural segments:
#   Hop 1: Regional External ALB + Cloud Armor (Edge & WAF)
#   Hop 2: Apigee Non-VPC-Peering Managed Runtime (Gateway Overhead vs Target Time)
#   Hop 3: Private Service Connect & Cloud Run Backend
#   Hop 4: Central Hub VPC & HA Cloud VPN (Hybrid Network Path)
#   Hop 5: On-Premises Core (Java Application + Relational Database)

module "observability" {
  source = "./modules/observability"

  compute_project_id     = var.compute_project_id
  compute_project_number = var.compute_project_number
  compute_region         = var.compute_region

  dashboard_name       = "Apigee End-to-End Latency & Observability Dashboard"
  enable_alerting      = true
  latency_threshold_ms = 2000

  labels = {
    environment = "dev"
    managed-by  = "terraform"
    domain      = "observability"
  }
}

output "observability_dashboard_id" {
  description = "Resource ID of the Cloud Monitoring Latency & Observability Dashboard."
  value       = module.observability.dashboard_id
}

output "observability_alert_high_latency_id" {
  description = "Resource ID of the high backend latency alert policy."
  value       = module.observability.alert_policy_high_latency_id
}

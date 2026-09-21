# Observability Module for Rocket Code Apigee Challenge
#
# This module implements the end-to-end observability and latency diagnostic strategy
# across the 5 architectural hops:
#   Hop 1: Regional External ALB + Cloud Armor (Edge & WAF)
#   Hop 2: Apigee Non-VPC-Peering Managed Runtime (Gateway Overhead vs Target Latency)
#   Hop 3: Private Service Connect & Cloud Run Backend
#   Hop 4: Central Hub VPC & HA Cloud VPN (Hybrid Network Path)
#   Hop 5: On-Premises Core (Java Application + Relational Database)
#
# Crucial Technical Defense / Oral Exam Rationale:
#   The Load Balancer terminates edge TLS and manages perimeter routing, but does NOT
#   solve downstream database or application bottlenecks during peak hours.
#   This module provides the diagnostic evidence to isolate the true latency source.

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

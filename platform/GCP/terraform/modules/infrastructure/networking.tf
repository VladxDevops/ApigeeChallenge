### VPC API Spoke and 3 Rightsized Subnets:
# Architecture Note:
# Subnets are rightsized to the bare minimum required for the Apigee challenge and GCP platform constraints,
# avoiding wasteful /24 allocations (256 IPs per subnet). All 3 subnets now fit compactly within a single /25
# (88 total allocated IPs vs 768 previously):
# 1. api_private:         /28 (16 IPs, 12 usable) - lean minimum for backend ILB forwarding rules and workloads.
# 2. regional_proxy_only: /26 (64 IPs, 60 usable) - GCP hard platform minimum for regional Envoy proxies.
# 3. psc_nat:             /29 (8 IPs, 4 usable)   - GCP hard platform minimum for PSC published service NAT.

# VPC: api-spoke-vpc:
resource "google_compute_network" "api_spoke" {
  name                    = "api-spoke-vpc"
  project                 = var.compute_project_id
  auto_create_subnetworks = false
  description             = "Customer-controlled API spoke VPC for the Apigee challenge."
}

# Subnet: api-private-us-south1:
# Sizing: /28 (16 IPs total; 4 reserved by GCP = 12 usable IPs).
# GCP Platform Minimum: /29 (8 IPs, 4 usable).
# Sizing Rationale: /28 provides a lean, safe allocation for internal load balancer forwarding rules,
# backend endpoints, and testing without address exhaustion, while reducing IP usage by 93.75% compared to /24.
resource "google_compute_subnetwork" "api_private" {
  name                     = "api-private-us-south1"
  project                  = var.compute_project_id
  region                   = var.compute_region
  network                  = google_compute_network.api_spoke.id
  ip_cidr_range            = var.api_private_subnet_cidr
  private_ip_google_access = true
  description              = "Private subnet for API/backend resources (lean /28 allocation, 12 usable IPs)."
}

# Subnet: api-proxy-only-us-south1:
# Sizing: /26 (64 IPs total; 4 reserved by GCP = 60 usable proxy IPs).
# GCP Platform Minimum: /26 (Google Cloud hard requirement; prefix lengths longer than /26 such as /27 or /28 are rejected by GCP).
# Sizing Rationale: Provides the bare minimum IP capacity required by GCP for Envoy-based Regional External/Internal ALBs.
resource "google_compute_subnetwork" "regional_proxy_only" {
  name          = "api-proxy-only-us-south1"
  project       = var.compute_project_id
  region        = var.compute_region
  network       = google_compute_network.api_spoke.id
  ip_cidr_range = var.proxy_only_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
  description   = "Proxy-only subnet for regional Envoy-based load balancers (GCP minimum /26, 60 usable proxy IPs)."
}

# Subnet: api-psc-nat-us-south1:
# Sizing: /29 (8 IPs total; 4 reserved by GCP = 4 usable NAT IPs).
# GCP Platform Minimum: /29 (Google Cloud supported range: /29 to /16).
# Sizing Rationale: Each connected consumer endpoint attachment consumes 1 NAT IP.
# Apigee southbound connectivity requires only 1-2 endpoint attachments, making /29 the exact bare minimum required.
resource "google_compute_subnetwork" "psc_nat" {
  name          = "api-psc-nat-us-south1"
  project       = var.compute_project_id
  region        = var.compute_region
  network       = google_compute_network.api_spoke.id
  ip_cidr_range = var.psc_nat_subnet_cidr
  purpose       = "PRIVATE_SERVICE_CONNECT"
  description   = "NAT subnet for PSC published service attachments (GCP minimum /29, 4 usable NAT IPs)."
}


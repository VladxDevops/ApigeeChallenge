###VPC API Spoke and 3 subnets: 

#VPC: api-spoke-vpc: 
resource "google_compute_network" "api_spoke" {
  name                    = "api-spoke-vpc"
  project                 = var.compute_project_id
  auto_create_subnetworks = false
  description             = "Customer-controlled API spoke VPC for the Apigee challenge."
}

#Subnet: api-private-us-south1:
resource "google_compute_subnetwork" "api_private" {
  name                     = "api-private-us-south1"
  project                  = var.compute_project_id
  region                   = var.compute_region
  network                  = google_compute_network.api_spoke.id
  ip_cidr_range            = var.api_private_subnet_cidr
  private_ip_google_access = true
  description              = "Private subnet for API/backend resources."
}

#Subnet: api-proxy-only-us-south1:
resource "google_compute_subnetwork" "regional_proxy_only" {
  name          = "api-proxy-only-us-south1"
  project       = var.compute_project_id
  region        = var.compute_region
  network       = google_compute_network.api_spoke.id
  ip_cidr_range = var.proxy_only_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
  description   = "Proxy-only subnet required by regional Envoy-based load balancers."
}

#Subnet: api-psc-nat-us-south1:
resource "google_compute_subnetwork" "psc_nat" {
  name          = "api-psc-nat-us-south1"
  project       = var.compute_project_id
  region        = var.compute_region
  network       = google_compute_network.api_spoke.id
  ip_cidr_range = var.psc_nat_subnet_cidr
  purpose       = "PRIVATE_SERVICE_CONNECT"
  description   = "NAT subnet used by Private Service Connect published services."
}

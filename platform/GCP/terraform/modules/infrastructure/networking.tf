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

###


### Private Service Connect - Producer Side
# Publishes a backend service to consumers (e.g. Apigee) via PSC.
# Chain: health check -> backend service -> internal ILB forwarding rule -> service attachment.

# Health check for the backend instances/NEG sitting behind the ILB.
resource "google_compute_health_check" "api_backend" {
  name                = "api-backend-hc"
  project             = var.compute_project_id
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port = var.api_backend_port
  }
}

# Regional internal backend service (backends attached separately, e.g. via a NEG or instance group).
resource "google_compute_region_backend_service" "api_backend" {
  name                  = "api-backend-service"
  project               = var.compute_project_id
  region                = var.compute_region
  network               = google_compute_network.api_spoke.id
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_health_check.api_backend.id]

  # backend {
  #   group = <your instance group / NEG self_link>
  # }
}

# Internal forwarding rule - this is the "target service" the Service Attachment publishes.
# Lives in api_private, matching architecture note about that subnet's purpose.
resource "google_compute_forwarding_rule" "api_ilb" {
  name                  = "api-ilb-forwarding-rule"
  project               = var.compute_project_id
  region                = var.compute_region
  network               = google_compute_network.api_spoke.id
  subnetwork            = google_compute_subnetwork.api_private.id
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  all_ports             = true
  backend_service       = google_compute_region_backend_service.api_backend.id
}

# Service Attachment - the actual PSC publication.
# nat_subnets pulls NAT IPs from dedicated psc_nat subnet (4 usable IPs).
resource "google_compute_service_attachment" "api_psc" {
  name                  = "api-psc-service-attachment"
  project               = var.compute_project_id
  region                = var.compute_region
  description           = "PSC service attachment publishing the API backend to authorized consumers (e.g. Apigee)."
  target_service        = google_compute_forwarding_rule.api_ilb.id
  connection_preference = "ACCEPT_MANUAL" # or "ACCEPT_AUTOMATIC" if you don't need per-consumer approval

  nat_subnets = [google_compute_subnetwork.psc_nat.id]

  # Explicitly allow-list the consumer project(s)/network(s) that may connect (e.g. Apigee's PSC network).
  consumer_accept_lists {
    project_id_or_num = var.apigee_consumer_project_id
    connection_limit  = 2 # matches your "1-2 endpoint attachments" sizing note
  }

  enable_proxy_protocol = false
}

### GCP`s Network connectivity API must be enabled? 
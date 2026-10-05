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

### Private Service Connect - Producer Side (Southbound: Apigee -> Cloud Run backend)
# Uses a Regional Internal HTTP(S) Load Balancer (Envoy-based / INTERNAL_MANAGED) fronting a
# Cloud Run serverless NEG, since GCP's Passthrough Network LB does not support serverless NEGs.
# This is also why regional_proxy_only exists in this VPC/region - Envoy-based LBs require it.

# Serverless NEG pointing at the Cloud Run service.
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "api-backend-run-neg"
  project               = var.compute_project_id
  region                = var.compute_region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }

  # Ensures the Cloud Run service exists before the NEG binds to it
  depends_on = [google_cloud_run_v2_service.api_backend]
}

# Regional backend service, INTERNAL_MANAGED scheme (proxy-based), pointing at the serverless NEG.
# No health check needed/allowed for serverless NEG backends - Cloud Run manages its own health.
resource "google_compute_region_backend_service" "api_backend" {
  name                  = "api-backend-service"
  project               = var.compute_project_id
  region                = var.compute_region
  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTP"

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }
}

# URL map and target HTTP proxy - required plumbing for a proxy-based regional ILB.
resource "google_compute_region_url_map" "api_urlmap" {
  name            = "api-backend-urlmap"
  project         = var.compute_project_id
  region          = var.compute_region
  default_service = google_compute_region_backend_service.api_backend.id
}

resource "google_compute_region_target_http_proxy" "api_proxy" {
  name    = "api-backend-http-proxy"
  project = var.compute_project_id
  region  = var.compute_region
  url_map = google_compute_region_url_map.api_urlmap.id
}

# Internal forwarding rule - the "target service" the Service Attachment publishes.
# subnetwork here is where the LB's own internal IP is allocated (api_private), NOT the
# proxy-only subnet - GCP's managed Envoy proxies use regional_proxy_only automatically,
# you don't reference it directly in any of these resources.
resource "google_compute_forwarding_rule" "api_ilb" {
  name                  = "api-ilb-forwarding-rule"
  project               = var.compute_project_id
  region                = var.compute_region
  network               = google_compute_network.api_spoke.id
  subnetwork            = google_compute_subnetwork.api_private.id
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_http_proxy.api_proxy.id

  # Ensures the proxy-only subnet exists before the LB is created.
  depends_on = [google_compute_subnetwork.regional_proxy_only]
}

# Allow specific service accounts (e.g. Apigee SA) to invoke the Cloud Run service.
resource "google_cloud_run_v2_service_iam_member" "cloud_run_invoker" {
  for_each = toset(var.cloud_run_invoker_members)

  project  = var.compute_project_id
  location = var.compute_region
  name     = var.cloud_run_service_name
  role     = "roles/run.invoker"
  member   = each.value

  depends_on = [google_cloud_run_v2_service.api_backend]
}

# Service Attachment - unchanged in shape, still targets the forwarding rule above.
resource "google_compute_service_attachment" "api_psc" {
  name                  = "api-psc-service-attachment"
  project               = var.compute_project_id
  region                = var.compute_region
  description           = "PSC service attachment publishing the Cloud Run backend to Apigee."
  target_service        = google_compute_forwarding_rule.api_ilb.id
  connection_preference = "ACCEPT_MANUAL"

  nat_subnets = [google_compute_subnetwork.psc_nat.id]

  consumer_accept_lists {
    project_id_or_num = var.apigee_consumer_project_id
    connection_limit  = 2
  }

  enable_proxy_protocol = false
}

### Private Service Connect - Northbound (Consumer: External ALB -> Apigee)
# Chain: reserved external IP -> forwarding rule (EXTERNAL_MANAGED) -> target HTTPS proxy
#        -> url map -> backend service (w/ Cloud Armor) -> PSC NEG -> Apigee's service attachment.
# EXTERNAL_MANAGED regional ALBs also require regional_proxy_only - the same proxy-only
# subnet already declared serves both this northbound LB and the southbound internal LB.

locals {
  # Auto-generate self-signed TLS cert if user provided placeholder or empty values
  use_custom_tls = var.tls_certificate != "" && !can(regex("PLACEHOLDER", var.tls_certificate)) && var.tls_private_key != "" && !can(regex("PLACEHOLDER", var.tls_private_key))

  effective_tls_private_key = local.use_custom_tls ? var.tls_private_key : (length(tls_private_key.default_self_signed) > 0 ? tls_private_key.default_self_signed[0].private_key_pem : "")
  effective_tls_certificate = local.use_custom_tls ? var.tls_certificate : (length(tls_self_signed_cert.default_self_signed) > 0 ? tls_self_signed_cert.default_self_signed[0].cert_pem : "")

  # Only provision Northbound PSC NEG & ALB if a valid non-placeholder Apigee Service Attachment URI is specified
  has_valid_apigee_attachment = var.apigee_northbound_service_attachment != "" && !can(regex("PLACEHOLDER|placeholder|api-psc-service-attachment", var.apigee_northbound_service_attachment))
}

# Auto-generated self-signed certificate fallback for dev / testing environments
resource "tls_private_key" "default_self_signed" {
  count     = local.has_valid_apigee_attachment && !local.use_custom_tls ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "default_self_signed" {
  count           = local.has_valid_apigee_attachment && !local.use_custom_tls ? 1 : 0
  private_key_pem = tls_private_key.default_self_signed[0].private_key_pem

  subject {
    common_name  = "api.example.com"
    organization = "Rocket Code Demo"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# PSC NEG referencing Apigee's northbound service attachment (Apigee gives you this URI
# once the org/instance is provisioned in non-VPC-peering mode).
resource "google_compute_region_network_endpoint_group" "apigee_psc_neg" {
  count                 = local.has_valid_apigee_attachment ? 1 : 0
  name                  = "apigee-northbound-psc-neg"
  project               = var.compute_project_id
  region                = var.compute_region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  network               = google_compute_network.api_spoke.id
  subnetwork            = google_compute_subnetwork.api_private.id
  psc_target_service    = var.apigee_northbound_service_attachment

  lifecycle {
    create_before_destroy = true
  }
}

# Cloud Armor policy attached to the backend service.
# Regional backend services require a regional security policy (google_compute_region_security_policy).
resource "google_compute_region_security_policy" "api_armor_policy" {
  name        = "api-armor-policy"
  project     = var.compute_project_id
  region      = var.compute_region
  description = "Baseline Cloud Armor policy for the northbound API entry point."

  rules {
    action      = "deny(403)"
    priority    = 1000
    description = "Example explicit deny rule."
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["9.9.9.9/32"] # placeholder deny rule - replace/remove as needed
      }
    }
  }

  rules {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow rule."
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

# Regional backend service fronting the PSC NEG, with Cloud Armor attached.
resource "google_compute_region_backend_service" "apigee_northbound" {
  count                 = local.has_valid_apigee_attachment ? 1 : 0
  name                  = "apigee-northbound-backend"
  project               = var.compute_project_id
  region                = var.compute_region
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = google_compute_region_security_policy.api_armor_policy.self_link

  backend {
    group           = google_compute_region_network_endpoint_group.apigee_psc_neg[0].id
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "apigee_northbound" {
  count           = local.has_valid_apigee_attachment ? 1 : 0
  name            = "apigee-northbound-urlmap"
  project         = var.compute_project_id
  region          = var.compute_region
  default_service = google_compute_region_backend_service.apigee_northbound[0].id
}

# SSL Cert - uses custom TLS cert if provided, or auto-generated self-signed cert if left empty/placeholder
resource "google_compute_region_ssl_certificate" "apigee_northbound" {
  count       = local.has_valid_apigee_attachment ? 1 : 0
  name        = "apigee-northbound-cert"
  project     = var.compute_project_id
  region      = var.compute_region
  private_key = local.effective_tls_private_key
  certificate = local.effective_tls_certificate
}

resource "google_compute_region_target_https_proxy" "apigee_northbound" {
  count            = local.has_valid_apigee_attachment ? 1 : 0
  name             = "apigee-northbound-https-proxy"
  project          = var.compute_project_id
  region           = var.compute_region
  url_map          = google_compute_region_url_map.apigee_northbound[0].id
  ssl_certificates = [google_compute_region_ssl_certificate.apigee_northbound[0].id]
}

resource "google_compute_address" "apigee_northbound_ip" {
  count        = local.has_valid_apigee_attachment ? 1 : 0
  name         = "apigee-northbound-external-ip"
  project      = var.compute_project_id
  region       = var.compute_region
  network_tier = "STANDARD" # regional external ALBs require STANDARD tier
}

resource "google_compute_forwarding_rule" "apigee_northbound" {
  count                 = local.has_valid_apigee_attachment ? 1 : 0
  name                  = "apigee-northbound-fwd-rule"
  project               = var.compute_project_id
  region                = var.compute_region
  ip_address            = google_compute_address.apigee_northbound_ip[0].id
  ip_protocol           = "TCP"
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_region_target_https_proxy.apigee_northbound[0].id
  network_tier          = "STANDARD"
  network               = var.api_spoke_network_id


  depends_on = [google_compute_subnetwork.regional_proxy_only]
}
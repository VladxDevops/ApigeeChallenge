################################################################################
# Security Layer Implementation
# Purpose: Implement Cloud Armor, firewall rules, IAM, and VPC Service Controls
#          for zero-trust architecture per security model and decisions.
#
# KEY PRINCIPLES:
# - Deny-all default, explicitly allow only required traffic flows
# - Least privilege IAM for all identities
# - All traffic encrypted (TLS/IPSec)
# - Comprehensive logging and audit trails
# - Clear separation of producer/consumer security boundaries (PSC model)
################################################################################

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

locals {
  api_vpc_name = "api-spoke-vpc"
}

################################################################################
# SECTION 1: CLOUD ARMOR (WAF) POLICY
# Minimal dev/demo policy: keep only the required baseline and a very small set of
# actionable OWASP protections. This avoids unnecessary production-grade rule complexity
# while still demonstrating an edge WAF and private backends that are not publicly exposed.
################################################################################

# Note: Regional Cloud Armor security policy (google_compute_region_security_policy.api_armor_policy)
# is deployed in modules/infrastructure for the regional external load balancer.
# Global Cloud Armor policy is omitted to avoid policy scope mismatch on regional backends.

################################################################################
# SECTION 2: MINIMAL DEFAULT FIREWALL RULES
# Keep a deny-all baseline and only the explicit allow rules required to support the demo.
################################################################################

# Default deny ingress: block all ingress by default.
resource "google_compute_firewall" "default_deny_ingress" {
  count     = var.firewall_enable_default_deny_ingress ? 1 : 0
  name      = "api-spoke-default-deny-ingress"
  project   = var.compute_project_id
  network   = var.api_spoke_network_id
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = var.firewall_log_config_enabled ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
  }

  description = "Default deny all ingress traffic. Allow rules are explicitly defined below."
}

# Default deny egress: keep disabled by default for the dev/demo environment unless stricter controls are needed.
resource "google_compute_firewall" "default_deny_egress" {
  count     = var.firewall_enable_default_deny_egress ? 1 : 0
  name      = "api-spoke-default-deny-egress"
  project   = var.compute_project_id
  network   = var.api_spoke_network_id
  direction = "EGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = var.firewall_log_config_enabled ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
  }

  description = "Default deny all egress traffic unless explicitly allowed."
}

# FLOW 1A: GCP health checks to backend services.
resource "google_compute_firewall" "allow_health_checks" {
  name      = "api-spoke-allow-health-checks"
  project   = var.compute_project_id
  network   = var.api_spoke_network_id
  direction = "INGRESS"
  priority  = 1000

  source_ranges      = ["35.191.0.0/16", "130.211.0.0/22"]
  destination_ranges = [var.api_private_subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  log_config {
    metadata = var.firewall_log_config_enabled ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
  }

  description = "Allow health checks from GCP health check ranges to backend services."
}

# FLOW 1B: Proxy-only subnet to backend services.
resource "google_compute_firewall" "allow_proxy_to_backends" {
  name      = "api-spoke-allow-proxy-to-backends"
  project   = var.compute_project_id
  network   = var.api_spoke_network_id
  direction = "INGRESS"
  priority  = 1001

  source_ranges      = [var.proxy_only_subnet_cidr]
  destination_ranges = [var.api_private_subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  log_config {
    metadata = var.firewall_log_config_enabled ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
  }

  description = "Allow proxy-only subnet traffic to private backend services."
}

# FLOW 2: Backend egress to the hub/on-premises network for private integration.
resource "google_compute_firewall" "allow_backend_to_hub" {
  name      = "api-spoke-allow-backend-to-hub"
  project   = var.compute_project_id
  network   = var.api_spoke_network_id
  direction = "EGRESS"
  priority  = 1000

  source_ranges      = [var.api_private_subnet_cidr]
  destination_ranges = [var.hub_vpc_cidr, var.onpremises_cidr]

  allow {
    protocol = "tcp"
    ports    = ["443", "80", "8080"]
  }

  log_config {
    metadata = var.firewall_log_config_enabled ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
  }

  description = "Allow the minimal backend egress needed for private hub/on-prem connectivity."
}

# FLOW 3: DNS resolution for internal services and more robust runtime behavior.
resource "google_compute_firewall" "allow_dns" {
  name      = "api-spoke-allow-dns"
  project   = var.compute_project_id
  network   = var.api_spoke_network_id
  direction = "EGRESS"
  priority  = 1002

  source_ranges      = [var.api_private_subnet_cidr, var.proxy_only_subnet_cidr]
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }

  log_config {
    metadata = var.firewall_log_config_enabled ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
  }

  description = "Allow DNS queries needed for service resolution."
}

# FLOW 4: Metadata access required by workloads running on GCP.
resource "google_compute_firewall" "allow_metadata_service" {
  name      = "api-spoke-allow-metadata-service"
  project   = var.compute_project_id
  network   = var.api_spoke_network_id
  direction = "EGRESS"
  priority  = 1003

  source_ranges      = [var.api_private_subnet_cidr]
  destination_ranges = ["169.254.169.254/32"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  log_config {
    metadata = var.firewall_log_config_enabled ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
  }

  description = "Allow access to the GCP metadata service required for workload identity and startup."
}

################################################################################
# SECTION 4: IAM SERVICE ACCOUNTS AND ROLE BINDINGS
# Implements least-privilege access for Cloud Run, Apigee, and operators.
################################################################################

# Service Account for Cloud Run workloads
resource "google_service_account" "cloud_run_sa" {
  count        = var.create_cloud_run_service_account ? 1 : 0
  account_id   = "cloud-run-backend-sa"
  project      = var.compute_project_id
  display_name = "Cloud Run Backend Service Account"
  description  = "Service account for Cloud Run backend workloads with minimal required permissions."

  depends_on = []
}

# NOTE: Cloud Run service IAM bindings (e.g., run.invoker) are defined in the infrastructure module
# where the actual google_cloud_run_v2_service resource exists.

# Cloud Run service account: Allow reading secrets from Secret Manager
resource "google_project_iam_member" "cloud_run_secret_accessor" {
  count   = var.create_cloud_run_service_account ? 1 : 0
  project = var.compute_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa[0].email}"
}

# Cloud Run service account: Allow writing logs to Cloud Logging
resource "google_project_iam_member" "cloud_run_log_writer" {
  count   = var.create_cloud_run_service_account ? 1 : 0
  project = var.compute_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa[0].email}"
}

# Cloud Run service account: Allow writing metrics to Cloud Monitoring
resource "google_project_iam_member" "cloud_run_metric_writer" {
  count   = var.create_cloud_run_service_account ? 1 : 0
  project = var.compute_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa[0].email}"
}

# Cloud Run service account: Allow reading container images from Artifact Registry
resource "google_project_iam_member" "cloud_run_ar_reader" {
  count   = var.create_cloud_run_service_account ? 1 : 0
  project = var.compute_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_sa[0].email}"
}

# Cloud Build execution identity: Grant Artifact Registry writer role
resource "google_project_iam_member" "cloud_build_ar_writer" {
  project = var.compute_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${var.compute_project_number}@cloudbuild.gserviceaccount.com"
}

# Cloud Build execution identity: Grant Cloud Logging writer role
resource "google_project_iam_member" "cloud_build_log_writer" {
  project = var.compute_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${var.compute_project_number}@cloudbuild.gserviceaccount.com"
}

# Note: Apigee admin service account and roles/apigee.admin role assignment
# are managed centrally inside modules/apigee.

################################################################################
# SECTION 5: SECRET MANAGER SETUP (baseline configuration)
# Provides secure storage for OAuth secrets, TLS keys, API credentials, etc.
################################################################################

# Enable Secret Manager API (via enable-gcp-services module)
# Note: This is handled in the enable-gcp-services module.
# Here we establish the security posture for secret creation and access.

# Grant Cloud Run service account access to secrets (examples)
# In practice, use google_secret_manager_secret_iam_member for specific secrets

################################################################################
# SECTION 6: DEV-STAGE NOTE
# VPC Service Controls are intentionally omitted for this exercise because the project is
# a demo/development deployment and should remain minimal, reproducible, and independent
# of organization-scoped access policies that are not required for a basic proof of concept.
################################################################################

################################################################################
# DATA SOURCES AND CONFIGURATION HELPERS
################################################################################

# Current project configuration
data "google_compute_network" "api_spoke" {
  name    = local.api_vpc_name
  project = var.compute_project_id

  depends_on = [] # Note: Assumes network is created by infrastructure module
}



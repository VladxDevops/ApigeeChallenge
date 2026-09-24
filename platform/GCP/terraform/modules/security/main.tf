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

# Primary Cloud Armor security policy
resource "google_compute_security_policy" "api_spoke_waf" {
  name        = var.cloud_armor_policy_name
  project     = var.compute_project_id
  description = var.cloud_armor_policy_description
  type        = "CLOUD_ARMOR"

  # Default rule: allow unmatched traffic by default for this dev/demo environment.
  rule {
    action   = var.cloud_armor_default_rule_action
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule for all traffic not matched by a more specific rule."
  }

  # Minimal OWASP protections for a demo environment.
  rule {
    action   = "deny(403)"
    priority = 100
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Block XSS attacks."
    preview     = var.cloud_armor_enable_preview_rules
  }

  rule {
    action   = "deny(403)"
    priority = 101
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Block SQL injection attacks."
    preview     = var.cloud_armor_enable_preview_rules
  }
}

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

# Service Account for Apigee administration (if applicable)
resource "google_service_account" "apigee_admin_sa" {
  count        = var.create_apigee_admin_service_account ? 1 : 0
  account_id   = "apigee-admin-sa"
  project      = var.compute_project_id
  display_name = "Apigee Administration Service Account"
  description  = "Service account for Apigee organization and proxy administration with minimal required permissions."

  depends_on = []
}

# Apigee admin service account: Allow Apigee org admin role (scoped to organization if applicable)
# Note: This requires an Apigee organization to exist. Binding is skipped if apigee_organization_id is empty.
resource "google_project_iam_member" "apigee_admin_role" {
  count   = var.create_apigee_admin_service_account && var.apigee_organization_id != "" ? 1 : 0
  project = var.compute_project_id
  role    = "roles/apigee.admin"
  member  = "serviceAccount:${google_service_account.apigee_admin_sa[0].email}"
}

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



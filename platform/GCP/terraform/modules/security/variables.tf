################################################################################
# Security Module Variables
# Purpose: Define all input variables for security components including
#          Cloud Armor, firewall rules, IAM, and VPC Service Controls
################################################################################

# Core project variables
variable "compute_project_id" {
  description = "Compute project ID for the GCP project where security resources will be created."
  type        = string
}

variable "compute_project_number" {
  description = "Compute project number for the GCP project."
  type        = string
}

variable "compute_region" {
  description = "Compute region for the GCP resources."
  type        = string
}

# Network references from infrastructure module
variable "api_spoke_network_id" {
  description = "ID of the API spoke VPC."
  type        = string
}

variable "api_private_subnet_cidr" {
  description = "CIDR range of the API private subnet."
  type        = string
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR range of the proxy-only subnet."
  type        = string
}

variable "psc_nat_subnet_cidr" {
  description = "CIDR range of the PSC NAT subnet."
  type        = string
}

# Assumed existing network ranges (from addressing plan)
variable "hub_vpc_cidr" {
  description = "CIDR range of the existing Hub VPC (assumed: 10.20.0.0/16)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "onpremises_cidr" {
  description = "CIDR range of on-premises networks (assumed: 10.0.0.0/12)."
  type        = string
  default     = "10.0.0.0/12"
}

# Cloud Armor configuration
variable "cloud_armor_policy_name" {
  description = "Name of the Cloud Armor security policy."
  type        = string
  default     = "api-spoke-waf-policy"
}

variable "cloud_armor_policy_description" {
  description = "Description for the Cloud Armor security policy."
  type        = string
  default     = "WAF policy for API spoke regional load balancer with OWASP Top 10 protection."
}

variable "cloud_armor_enable_preview_rules" {
  description = "Enable Cloud Armor rule preview mode for testing (non-blocking)."
  type        = bool
  default     = false
}

variable "cloud_armor_default_rule_action" {
  description = "Default action for traffic not matching explicit rules: 'allow' or 'deny'."
  type        = string
  default     = "allow"
  validation {
    condition     = contains(["allow", "deny"], var.cloud_armor_default_rule_action)
    error_message = "Default rule action must be 'allow' or 'deny'."
  }
}

# Rate limiting configuration
variable "cloud_armor_rate_limit_options" {
  description = "Rate limiting configuration for Cloud Armor. Disabled by default for the dev/demo stage."
  type = object({
    enable_rate_limiting = bool
    max_rate_per_ip      = number
    ban_duration_seconds = number
  })
  default = {
    enable_rate_limiting = false
    max_rate_per_ip      = 0
    ban_duration_seconds = 0
  }
}

# Firewall rules configuration
variable "firewall_enable_default_deny_ingress" {
  description = "Enable default deny firewall rule for all ingress traffic."
  type        = bool
  default     = true
}

variable "firewall_enable_default_deny_egress" {
  description = "Enable default deny firewall rule for all egress traffic."
  type        = bool
  default     = false
}

variable "firewall_log_config_enabled" {
  description = "Enable logging for firewall rules."
  type        = bool
  default     = true
}

# Health check configuration
variable "health_check_interval_sec" {
  description = "Health check interval in seconds."
  type        = number
  default     = 10
}

variable "health_check_timeout_sec" {
  description = "Health check timeout in seconds."
  type        = number
  default     = 5
}

# IAM configuration
# Cloud Run: 

## Cloud Run Service Account LDAP: 
variable "cloud_run_service_account_ldap" {
  description = "LDAP name for the Cloud Run service account to be created in the IAM module. It will be used by the Cloud Run service for execution."
  type        = string
}

variable "create_cloud_run_service_account" {
  description = "Create a dedicated service account for Cloud Run workloads."
  type        = bool
  default     = true
}

variable "create_apigee_admin_service_account" {
  description = "Create a dedicated service account for Apigee administration."
  type        = bool
  default     = true
}

variable "terraform_deployer_service_account" {
  description = "Service account email for the Terraform deployer (for RBAC configuration)."
  type        = string
}

variable "apigee_organization_id" {
  description = "Apigee organization ID (if applicable)."
  type        = string
  default     = ""
}

# VPC Service Controls configuration
variable "create_vpc_service_perimeter" {
  description = "Create a VPC Service Controls perimeter for zero-trust access. Disabled by default for the dev/demo stage."
  type        = bool
  default     = false
}

variable "vpc_sc_perimeter_name" {
  description = "Name of the VPC Service Controls perimeter."
  type        = string
  default     = "api_spoke_perimeter"
}

variable "vpc_sc_restricted_services" {
  description = "List of GCP services to include in the VPC Service Controls perimeter."
  type        = list(string)
  default = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com"
  ]
}

# Tags and labels
variable "environment" {
  description = "Environment name (e.g., 'dev', 'staging', 'prod')."
  type        = string
  default     = "dev"
}

variable "common_labels" {
  description = "Common labels to apply to all resources."
  type        = map(string)
  default = {
    managed_by = "terraform"
    project    = "apigee-challenge"
    component  = "security"
  }
}

# Secret Manager configuration
variable "enable_secret_manager" {
  description = "Enable Secret Manager resources for storing sensitive application configuration."
  type        = bool
  default     = true
}

variable "secret_api_key" {
  description = "Placeholder API key secret value (replace in actual deployment)."
  type        = string
  default     = "PLACEHOLDER_API_KEY_REPLACE_ME"
  sensitive   = true
}

variable "secret_db_password" {
  description = "Placeholder database password secret value (replace in actual deployment)."
  type        = string
  default     = "PLACEHOLDER_DB_PASSWORD_REPLACE_ME"
  sensitive   = true
}

variable "secret_oauth_client_secret" {
  description = "Placeholder OAuth client secret value (replace in actual deployment)."
  type        = string
  default     = "PLACEHOLDER_OAUTH_SECRET_REPLACE_ME"
  sensitive   = true
}

variable "secret_jwt_signing_key" {
  description = "Placeholder JWT signing key secret value (replace in actual deployment)."
  type        = string
  default     = "PLACEHOLDER_JWT_KEY_REPLACE_ME"
  sensitive   = true
}

################################################################################
# Security Module Outputs
# Exports security resources for consumption by other modules and for
# operator visibility into security configuration.
################################################################################

# Cloud Armor Security Policy
output "cloud_armor_policy_id" {
  description = "ID of the Cloud Armor security policy for WAF protection."
  value       = google_compute_security_policy.api_spoke_waf.id
}

output "cloud_armor_policy_name" {
  description = "Name of the Cloud Armor security policy (attach to load balancers)."
  value       = google_compute_security_policy.api_spoke_waf.name
}

output "cloud_armor_policy_self_link" {
  description = "Self-link resource path for the Cloud Armor security policy."
  value       = google_compute_security_policy.api_spoke_waf.self_link
}

output "cloud_armor_rules_summary" {
  description = "Summary of Cloud Armor security policy rules."
  value = {
    xss_protection    = "Enabled (Rule 100)"
    sql_injection     = "Enabled (Rule 101)"
    lfi_protection    = "Enabled (Rule 102)"
    rce_protection    = "Enabled (Rule 103)"
    protocol_attacks  = "Enabled (Rule 104)"
    scanner_detection = "Enabled (Rule 105)"
    rate_limiting     = var.cloud_armor_rate_limit_options.enable_rate_limiting ? "Enabled (Rule 106, max ${var.cloud_armor_rate_limit_options.max_rate_per_ip} req/IP)" : "Disabled"
    default_action    = var.cloud_armor_default_rule_action
  }
}

# Service Accounts
output "cloud_run_service_account_email" {
  description = "Email of the Cloud Run backend service account (for IAM bindings and workload identity)."
  value       = var.create_cloud_run_service_account ? google_service_account.cloud_run_sa[0].email : null
}

output "cloud_run_service_account_id" {
  description = "Unique ID of the Cloud Run service account."
  value       = var.create_cloud_run_service_account ? google_service_account.cloud_run_sa[0].unique_id : null
}

output "cloud_run_service_account_name" {
  description = "Name of the Cloud Run service account."
  value       = var.create_cloud_run_service_account ? google_service_account.cloud_run_sa[0].account_id : null
}

output "apigee_admin_service_account_email" {
  description = "Email of the Apigee administration service account (for Apigee org/proxy management)."
  value       = var.create_apigee_admin_service_account ? google_service_account.apigee_admin_sa[0].email : null
}

output "apigee_admin_service_account_id" {
  description = "Unique ID of the Apigee admin service account."
  value       = var.create_apigee_admin_service_account ? google_service_account.apigee_admin_sa[0].unique_id : null
}

# Firewall Rules Summary
output "firewall_rules_summary" {
  description = "Summary of firewall rules deployed for API spoke VPC."
  value = {
    default_deny_rules = {
      ingress = var.firewall_enable_default_deny_ingress ? "Enabled (priority 65534)" : "Disabled"
      egress  = var.firewall_enable_default_deny_egress ? "Enabled (priority 65534)" : "Disabled"
    }
    allow_rules = {
      health_checks     = "Enabled (GCP health check ranges → backends)"
      proxy_to_backends = "Enabled (proxy-only subnet → private subnet)"
      psc_northbound    = "Enabled (proxy → Apigee via PSC)"
      psc_southbound    = "Enabled (Apigee via PSC → backends)"
      to_hub_vpc        = "Enabled (private subnet → hub/on-prem)"
      from_hub_vpc      = "Enabled (hub/on-prem → private subnet)"
      dns               = "Enabled (DNS queries)"
      metadata_service  = "Enabled (GCP metadata service access)"
    }
    logging_enabled = var.firewall_log_config_enabled
  }
}

# VPC Service Controls (if enabled)
output "vpc_sc_perimeter_name" {
  description = "Name of the VPC Service Controls perimeter (if created for zero-trust access)."
  value       = var.create_vpc_service_perimeter ? google_access_context_manager_service_perimeter.api_spoke_perimeter[0].name : null
}

output "vpc_sc_restricted_services" {
  description = "List of GCP services restricted by VPC Service Controls perimeter."
  value       = var.create_vpc_service_perimeter ? var.vpc_sc_restricted_services : null
}

# Security Configuration Summary (for operators and documentation)
output "security_configuration_summary" {
  description = "Complete summary of security layer configuration."
  value = {
    waf_enabled = true
    waf_policy  = google_compute_security_policy.api_spoke_waf.name

    network_policy = "Zero-trust: Deny-all default with explicit allow rules for documented traffic flows"

    firewall_flows_protected = [
      "Ingress: Health checks → Backends",
      "Ingress: Regional LB (proxy-only subnet) → Backends (private subnet)",
      "Ingress: PSC Northbound (Regional LB → Apigee Runtime)",
      "Ingress: PSC Southbound (Apigee Runtime → Service Attachment)",
      "Ingress: Return traffic from Hub VPC and On-Premises",
      "Egress: Backends → Hub VPC and On-Premises (hybrid connectivity)",
      "Egress: DNS queries (service discovery)",
      "Egress: GCP metadata service (workload identity)"
    ]

    iam_model = "Least-privilege with dedicated service accounts for Cloud Run and Apigee administration"

    service_accounts = {
      cloud_run = var.create_cloud_run_service_account ? "Enabled (read secrets, write logs/metrics)" : "Disabled"
      apigee    = var.create_apigee_admin_service_account ? "Enabled (Apigee organization admin)" : "Disabled"
    }

    encryption_in_transit = [
      "External TLS (LB → Client)",
      "Private Google network (PSC Northbound)",
      "Private Google network (PSC Southbound)",
      "IPSec (VPN to on-premises)"
    ]

    audit_logging = var.firewall_log_config_enabled ? "Enabled for Cloud Armor, Firewall, and IAM events" : "Disabled"

    zero_trust_perimeter = var.create_vpc_service_perimeter ? "Enabled (VPC Service Controls for restricted API access)" : "Disabled"
  }
}

# Operational Validation Checklist
output "deployment_validation_checklist" {
  description = "Checklist for operators to validate security layer deployment."
  value = {
    step_1_verify_cloud_armor = "Check GCP Console → Security → Cloud Armor → ${google_compute_security_policy.api_spoke_waf.name} and confirm all 7 OWASP rules are active"

    step_2_verify_firewall_rules = "Check GCP Console → VPC Network → Firewall rules and confirm all 8 rules are deployed with logging enabled"

    step_3_verify_iam_bindings = "Check GCP Console → IAM & Admin → Service Accounts and confirm: cloud-run-backend-sa and apigee-admin-sa exist with expected role bindings"

    step_4_verify_psc_connectivity = "After load balancer and PSC service attachment deployment, verify traffic can flow: ALB → Apigee (northbound) and Apigee → Backends (southbound)"

    step_5_verify_firewall_logs = "Check Cloud Logging (GCP Console → Logging) and filter for VPC Flow Logs (compute.googleapis.com) and Cloud Armor logs (compute.googleapis.com/security_policies)"

    step_6_verify_deny_defaults = "Run a test: attempt traffic from undefined source → private subnet. It should be blocked and logged."

    step_7_verify_secrets = "Deploy a test secret to Secret Manager, bind it to Cloud Run SA, and verify the SA can read it via curl/gcloud in the container"
  }
}

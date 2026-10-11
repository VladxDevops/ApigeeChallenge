module "infrastructure" {
  source = "./modules/infrastructure"

  compute_project_id                 = var.compute_project_id
  compute_project_number             = var.compute_project_number
  compute_region                     = var.compute_region
  #Before:
  #api_spoke_network_id               = var.api_spoke_network_id
  #Replaced by: 
  hub_network_self_link = module.hybrid_connectivity.hub_network_self_link
  terraform_remote_state_bucket_name = var.terraform_remote_state_bucket_name
  terraform_deployer_service_account = var.terraform_deployer_service_account
  api_vpc_cidr                       = var.api_vpc_cidr
  api_private_subnet_cidr            = var.api_private_subnet_cidr
  proxy_only_subnet_cidr             = var.proxy_only_subnet_cidr
  psc_nat_subnet_cidr                = var.psc_nat_subnet_cidr
  hub_network_self_link = var.hub_network_self_link
  #api_backend_port = var.api_backend_port
  apigee_consumer_project_id      = var.compute_project_id
  cloud_run_service_name          = var.cloud_run_service_name
  cloud_run_image                 = var.cloud_run_image
  cloud_run_container_port        = var.cloud_run_container_port
  cloud_run_service_account_email = var.cloud_run_service_account_email
  cloud_run_min_instances         = var.cloud_run_min_instances
  cloud_run_max_instances         = var.cloud_run_max_instances
  cloud_run_cpu_limit             = var.cloud_run_cpu_limit
  cloud_run_memory_limit          = var.cloud_run_memory_limit
  # NOTE: The northbound PSC attachment URI is only known after the Apigee module exists.
  # Using an unknown value from module.apigee in the same plan makes count conditional
  # invalid. Keep the gate driven by the static input variable and set the URI in a
  # subsequent apply once the Apigee attachment is available.
  apigee_northbound_service_attachment = var.apigee_northbound_service_attachment
  tls_private_key                      = var.tls_private_key
  tls_certificate                      = var.tls_certificate
  cloud_run_invoker_members = [
    "serviceAccount:${module.apigee.apigee_service_account_email}"
  ]
  cloud_run_vpc_connector_cidr = var.cloud_run_vpc_connector_cidr
}

################################################################################
# SECURITY MODULE
# Purpose: Deploy Cloud Armor WAF, firewall rules, IAM, and VPC Service Controls
# Status: Zero-trust architecture with deny-all default and explicit allow-list
################################################################################

module "security" {
  source = "./modules/security"

  # Core project variables
  compute_project_id                 = var.compute_project_id
  compute_project_number             = var.compute_project_number
  compute_region                     = var.compute_region
  terraform_deployer_service_account = var.terraform_deployer_service_account


  # Network references from infrastructure module
  api_spoke_network_id    = module.infrastructure.api_spoke_network_id
  api_private_subnet_cidr = var.api_private_subnet_cidr
  proxy_only_subnet_cidr  = var.proxy_only_subnet_cidr
  psc_nat_subnet_cidr     = var.psc_nat_subnet_cidr


  # Assumed existing network ranges (from addressing plan)
  hub_vpc_cidr    = var.hub_vpc_cidr    # Default: 10.20.0.0/16
  onpremises_cidr = var.onpremises_cidr # Default: 10.0.0.0/12


  # Cloud Armor configuration
  cloud_armor_policy_name          = "api-spoke-waf-policy"
  cloud_armor_default_rule_action  = "allow" # Allow by default, deny malicious patterns
  cloud_armor_enable_preview_rules = false   # Set to true for testing/preview

  cloud_armor_rate_limit_options = {
    enable_rate_limiting = true
    max_rate_per_ip      = 10000 # 10k requests per IP per time window
    ban_duration_seconds = 600   # 10 minutes
  }


  # Firewall rules configuration
  firewall_enable_default_deny_ingress = true  # Deny-all default (zero-trust)
  firewall_enable_default_deny_egress  = false # Allow routine egress (logs, metadata)
  firewall_log_config_enabled          = true  # Log all deny/allow decisions


  # Health check configuration
  health_check_interval_sec = 10 # Standard GCP health check interval
  health_check_timeout_sec  = 5  # Standard timeout


  # IAM configuration
  create_cloud_run_service_account    = true                  # Cloud Run workload identity
  create_apigee_admin_service_account = true                  # Apigee admin operations
  apigee_organization_id              = "Apigee Organization" # Set to Apigee org ID if using


  # VPC Service Controls (optional zero-trust perimeter)
  create_vpc_service_perimeter = false # Enable in production for restricted API access
  vpc_sc_restricted_services = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com"
  ]

  # Tags and labels
  environment = "dev"
  common_labels = {
    managed_by = "terraform"
    project    = "apigee-challenge"
    component  = "security"
  }

  # Secret Manager configuration
  enable_secret_manager      = var.enable_secret_manager
  secret_api_key             = var.secret_api_key
  secret_db_password         = var.secret_db_password
  secret_oauth_client_secret = var.secret_oauth_client_secret
  secret_jwt_signing_key     = var.secret_jwt_signing_key

  # Module dependency
  depends_on = [module.infrastructure]
}

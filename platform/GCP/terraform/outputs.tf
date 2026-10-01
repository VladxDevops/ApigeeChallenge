# Root Module Outputs for Rocket Code Apigee Challenge Architecture

output "api_spoke_network_id" {
  description = "ID of the API spoke VPC."
  value       = module.infrastructure.api_spoke_network_id
}

output "api_private_subnet_id" {
  description = "ID of the primary private API subnet."
  value       = module.infrastructure.api_private_subnet_id
}

output "proxy_only_subnet_id" {
  description = "ID of the regional managed proxy-only subnet."
  value       = module.infrastructure.proxy_only_subnet_id
}

output "psc_nat_subnet_id" {
  description = "ID of the Private Service Connect NAT subnet."
  value       = module.infrastructure.psc_nat_subnet_id
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run backend service."
  value       = module.infrastructure.cloud_run_service_name
}

output "cloud_run_service_url" {
  description = "URL of the Cloud Run backend service."
  value       = module.infrastructure.cloud_run_service_url
}

output "terraform_deployer_sa_email" {
  description = "Email of the Terraform deployer service account."
  value       = module.iam.terraform_deployer_sa_email
}

output "cloud_armor_policy_name" {
  description = "Name of the Cloud Armor WAF security policy."
  value       = module.infrastructure.api_armor_policy_name
}

output "cloud_run_service_account_email" {
  description = "Email of the dedicated Cloud Run workload identity."
  value       = module.security.cloud_run_service_account_email
}

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

# Northbound IP address output
output "northbound_ip" {
  description = "Reserved regional IP address for the northbound entry point. Use as the --resolve target for api.example.com."
  value       = module.infrastructure.apigee_northbound_ip_address
}

# Southbound Apigee endpoint attachment output
output "apigee_endpoint_attachment_host" {
  description = "Host IP/address of the southbound Apigee endpoint attachment."
  value       = module.apigee.endpoint_attachment_host
}

output "compute_project_id" {
  description = "GCP project ID where the API platform is deployed."
  value       = var.compute_project_id
}

output "apigee_service_account_email" {
  description = "Email of the service account used to run the deployed Apigee proxy."
  value       = module.apigee.apigee_service_account_email
}
# Outputs for Security Module

output "cloud_armor_policy_id" {
  description = "ID of the Cloud Armor security policy."
  value       = google_compute_security_policy.api_spoke_waf.id
}

output "cloud_armor_policy_name" {
  description = "Name of the Cloud Armor security policy."
  value       = google_compute_security_policy.api_spoke_waf.name
}

output "cloud_armor_policy_self_link" {
  description = "Self-link of the Cloud Armor security policy."
  value       = google_compute_security_policy.api_spoke_waf.self_link
}

output "cloud_run_service_account_email" {
  description = "Email of the Cloud Run service account."
  value       = var.create_cloud_run_service_account ? google_service_account.cloud_run_sa[0].email : null
}

output "cloud_run_service_account_id" {
  description = "Unique ID of the Cloud Run service account."
  value       = var.create_cloud_run_service_account ? google_service_account.cloud_run_sa[0].unique_id : null
}

output "apigee_admin_service_account_email" {
  description = "Email of the Apigee admin service account."
  value       = var.create_apigee_admin_service_account ? google_service_account.apigee_admin_sa[0].email : null
}

output "secret_api_key_name" {
  description = "Name of the API key secret."
  value       = var.enable_secret_manager ? google_secret_manager_secret.api_key[0].name : ""
}

output "secret_db_password_name" {
  description = "Name of the database password secret."
  value       = var.enable_secret_manager ? google_secret_manager_secret.db_password[0].name : ""
}

output "secret_oauth_client_secret_name" {
  description = "Name of the OAuth client secret."
  value       = var.enable_secret_manager ? google_secret_manager_secret.oauth_client_secret[0].name : ""
}

output "secret_jwt_signing_key_name" {
  description = "Name of the JWT signing key secret."
  value       = var.enable_secret_manager ? google_secret_manager_secret.jwt_signing_key[0].name : ""
}

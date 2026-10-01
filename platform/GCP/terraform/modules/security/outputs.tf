# Outputs for Security Module

output "cloud_run_service_account_email" {
  description = "Email of the Cloud Run service account."
  value       = var.create_cloud_run_service_account ? google_service_account.cloud_run_sa[0].email : null
}

output "cloud_run_service_account_id" {
  description = "Unique ID of the Cloud Run service account."
  value       = var.create_cloud_run_service_account ? google_service_account.cloud_run_sa[0].unique_id : null
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

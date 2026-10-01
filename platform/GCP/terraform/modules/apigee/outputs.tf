# Outputs for Apigee Module

output "organization_id" {
  description = "ID of the Apigee organization."
  value       = google_apigee_organization.org.id
}

output "org_name" {
  description = "Name of the Apigee organization."
  value       = google_apigee_organization.org.name
}

output "instance_id" {
  description = "ID of the Apigee instance."
  value       = google_apigee_instance.apigee_instance.id
}

output "northbound_service_attachment" {
  description = "Service attachment URI exported by Apigee instance for northbound PSC consumer connection."
  value       = google_apigee_instance.apigee_instance.service_attachment
}

output "endpoint_attachment_id" {
  description = "ID of the southbound Apigee endpoint attachment."
  value       = google_apigee_endpoint_attachment.cloud_run_backend.id
}

output "endpoint_attachment_host" {
  description = "Host IP/address of the southbound Apigee endpoint attachment."
  value       = google_apigee_endpoint_attachment.cloud_run_backend.host
}

output "apigee_service_account_email" {
  description = "The email address of the Apigee service account."
  value       = google_service_account.apigee-admin-sa.email
}

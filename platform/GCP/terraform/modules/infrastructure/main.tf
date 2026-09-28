output "api_spoke_network_id" {
  description = "ID of the API spoke VPC."
  value       = google_compute_network.api_spoke.id
}

output "api_private_subnet_id" {
  description = "ID of the primary private API subnet."
  value       = google_compute_subnetwork.api_private.id
}

output "proxy_only_subnet_id" {
  description = "ID of the regional managed proxy-only subnet."
  value       = google_compute_subnetwork.regional_proxy_only.id
}

output "psc_nat_subnet_id" {
  description = "ID of the Private Service Connect NAT subnet."
  value       = google_compute_subnetwork.psc_nat.id
}

output "api_psc_service_attachment_id" {
  description = "ID of the southbound PSC service attachment published to Apigee."
  value       = google_compute_service_attachment.api_psc.id
}
output "apigee_northbound_ip_address" {
  description = "Reserved regional IP address used as the northbound entry point (null if not created)."
  value       = one(google_compute_address.apigee_northbound_ip[*].address)
}
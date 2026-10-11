output "hub_network_id" {
  description = "ID of the simulated Hub VPC. Null when simulate_hub_and_onpremises is false."
  value       = try(google_compute_network.hub[0].id, null)
}

output "onprem_network_id" {
  description = "ID of the simulated on-premises VPC. Null when simulate_hub_and_onpremises is false."
  value       = try(google_compute_network.onprem_sim[0].id, null)
}

output "hub_router_name" {
  description = "Name of the hub-side Cloud Router, for future spoke-to-hub wiring."
  value       = try(google_compute_router.hub[0].name, null)
}

output "vpn_tunnel_names" {
  description = "All four tunnel names, for terraform plan/apply verification."
  value = var.simulate_hub_and_onpremises ? [
    google_compute_vpn_tunnel.hub_tunnel0[0].name,
    google_compute_vpn_tunnel.hub_tunnel1[0].name,
    google_compute_vpn_tunnel.onprem_tunnel0[0].name,
    google_compute_vpn_tunnel.onprem_tunnel1[0].name,
  ] : []
}

output "hub_network_self_link" {
  description = "Self link of the simulated hub VPC (null when the hub is not simulated)."
  value       = var.simulate_hub_and_onpremises ? google_compute_network.hub[0].self_link : null
}
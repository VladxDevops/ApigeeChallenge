resource "google_compute_network_peering" "spoke_to_hub" {
  name                 = "api-spoke-to-hub"
  network              = google_compute_network.api_spoke.self_link
  peer_network         = var.hub_network_self_link
  import_custom_routes = true
  export_custom_routes = false
}

resource "google_compute_network_peering" "hub_to_spoke" {
  name                 = "hub-to-api-spoke"
  network              = var.hub_network_self_link
  peer_network         = google_compute_network.api_spoke.self_link
  export_custom_routes = true
  import_custom_routes = false

  depends_on = [google_compute_network_peering.spoke_to_hub]
}
################################################################################
# SIMULATED HUB VPC
# Stands in for network-architecture.md's "existing Hub VPC" external dependency.
# Real hub CIDRs/routes are still unconfirmed (see network-architecture.md);
# this network exists only so the demo has something real to VPN against.
################################################################################

resource "google_compute_network" "hub" {
  count                   = var.simulate_hub_and_onpremises ? 1 : 0
  name                    = "sim-hub-vpc"
  project                 = var.compute_project_id
  auto_create_subnetworks = false
  description             = "Simulated Hub VPC for hybrid-connectivity demo. Not the real organizational hub."
}

resource "google_compute_subnetwork" "hub" {
  count         = var.simulate_hub_and_onpremises ? 1 : 0
  name          = "sim-hub-subnet-${var.compute_region}"
  project       = var.compute_project_id
  network       = google_compute_network.hub[0].id
  region        = var.compute_region
  ip_cidr_range = var.hub_subnet_cidr
}

################################################################################
# SIMULATED ON-PREMISES NETWORK
# Stands in for the real data center. Represents the Java app / RDBMS tier
# referenced in traffic-flows.md and Architecture-baseline.md.
################################################################################

resource "google_compute_network" "onprem_sim" {
  count                   = var.simulate_hub_and_onpremises ? 1 : 0
  name                    = "sim-onprem-vpc"
  project                 = var.compute_project_id
  auto_create_subnetworks = false
  description             = "Simulated on-premises network for hybrid-connectivity demo. Not real data-center infrastructure."
}

resource "google_compute_subnetwork" "onprem_sim" {
  count         = var.simulate_hub_and_onpremises ? 1 : 0
  name          = "sim-onprem-subnet-${var.compute_region}"
  project       = var.compute_project_id
  network       = google_compute_network.onprem_sim[0].id
  region        = var.compute_region
  ip_cidr_range = var.onprem_subnet_cidr
}

################################################################################
# HA VPN: hub <-> on-premises (GCP-to-GCP HA VPN gateway pattern)
# Two tunnels per side for the standard 99.99% SLA topology, dynamic (BGP) routing.
################################################################################

resource "google_compute_ha_vpn_gateway" "hub" {
  count   = var.simulate_hub_and_onpremises ? 1 : 0
  name    = "sim-hub-vpn-gw"
  project = var.compute_project_id
  region  = var.compute_region
  network = google_compute_network.hub[0].id
}

resource "google_compute_ha_vpn_gateway" "onprem_sim" {
  count   = var.simulate_hub_and_onpremises ? 1 : 0
  name    = "sim-onprem-vpn-gw"
  project = var.compute_project_id
  region  = var.compute_region
  network = google_compute_network.onprem_sim[0].id
}

resource "google_compute_router" "hub" {
  count   = var.simulate_hub_and_onpremises ? 1 : 0
  name    = "sim-hub-router"
  project = var.compute_project_id
  region  = var.compute_region
  network = google_compute_network.hub[0].id

    bgp {
    asn               = var.hub_router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    advertised_ip_ranges {
      range       = var.api_vpc_cidr
      description = "API spoke VPC, reachable through the hub via VPC peering"
    }
  }
}

resource "google_compute_router" "onprem_sim" {
  count   = var.simulate_hub_and_onpremises ? 1 : 0
  name    = "sim-onprem-router"
  project = var.compute_project_id
  region  = var.compute_region
  network = google_compute_network.onprem_sim[0].id

  bgp {
    asn = var.onprem_router_asn
  }
}

# Shared secret is generated, never a literal in code or tfvars, per security-model.md
# ("Do not commit ... VPN pre-shared keys").
resource "random_password" "vpn_shared_secret" {
  count            = var.simulate_hub_and_onpremises ? 1 : 0
  length           = 32
  special          = true
  override_special = "-_"
}

resource "google_secret_manager_secret" "vpn_shared_secret" {
  count     = var.simulate_hub_and_onpremises && var.enable_secret_manager ? 1 : 0
  project   = var.compute_project_id
  secret_id = "sim-hybrid-vpn-shared-secret"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "vpn_shared_secret" {
  count       = var.simulate_hub_and_onpremises && var.enable_secret_manager ? 1 : 0
  secret      = google_secret_manager_secret.vpn_shared_secret[0].id
  secret_data = random_password.vpn_shared_secret[0].result
}

locals {
  # Link-local /30s for BGP sessions. Not part of the addressing plan's RFC1918
  # allocations - these are the standard GCP HA VPN interface ranges.
  tunnel0_hub_ip    = "169.254.0.1/30"
  tunnel0_onprem_ip = "169.254.0.2/30"
  tunnel1_hub_ip    = "169.254.1.1/30"
  tunnel1_onprem_ip = "169.254.1.2/30"
}

# --- Tunnels from the hub side ---

resource "google_compute_vpn_tunnel" "hub_tunnel0" {
  count                 = var.simulate_hub_and_onpremises ? 1 : 0
  name                  = "sim-hub-tunnel0"
  project               = var.compute_project_id
  region                = var.compute_region
  vpn_gateway           = google_compute_ha_vpn_gateway.hub[0].id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.onprem_sim[0].id
  shared_secret         = random_password.vpn_shared_secret[0].result
  router                = google_compute_router.hub[0].id
  vpn_gateway_interface = 0
}

resource "google_compute_vpn_tunnel" "hub_tunnel1" {
  count                 = var.simulate_hub_and_onpremises ? 1 : 0
  name                  = "sim-hub-tunnel1"
  project               = var.compute_project_id
  region                = var.compute_region
  vpn_gateway           = google_compute_ha_vpn_gateway.hub[0].id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.onprem_sim[0].id
  shared_secret         = random_password.vpn_shared_secret[0].result
  router                = google_compute_router.hub[0].id
  vpn_gateway_interface = 1
}

# --- Tunnels from the on-prem side ---

resource "google_compute_vpn_tunnel" "onprem_tunnel0" {
  count                 = var.simulate_hub_and_onpremises ? 1 : 0
  name                  = "sim-onprem-tunnel0"
  project               = var.compute_project_id
  region                = var.compute_region
  vpn_gateway           = google_compute_ha_vpn_gateway.onprem_sim[0].id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.hub[0].id
  shared_secret         = random_password.vpn_shared_secret[0].result
  router                = google_compute_router.onprem_sim[0].id
  vpn_gateway_interface = 0
}

resource "google_compute_vpn_tunnel" "onprem_tunnel1" {
  count                 = var.simulate_hub_and_onpremises ? 1 : 0
  name                  = "sim-onprem-tunnel1"
  project               = var.compute_project_id
  region                = var.compute_region
  vpn_gateway           = google_compute_ha_vpn_gateway.onprem_sim[0].id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.hub[0].id
  shared_secret         = random_password.vpn_shared_secret[0].result
  router                = google_compute_router.onprem_sim[0].id
  vpn_gateway_interface = 1
}

# --- Router interfaces + BGP peers, hub side ---

resource "google_compute_router_interface" "hub_if0" {
  count      = var.simulate_hub_and_onpremises ? 1 : 0
  name       = "sim-hub-if0"
  project    = var.compute_project_id
  region     = var.compute_region
  router     = google_compute_router.hub[0].name
  ip_range   = local.tunnel0_hub_ip
  vpn_tunnel = google_compute_vpn_tunnel.hub_tunnel0[0].name
}

resource "google_compute_router_peer" "hub_peer0" {
  count           = var.simulate_hub_and_onpremises ? 1 : 0
  name            = "sim-hub-peer0"
  project         = var.compute_project_id
  region          = var.compute_region
  router          = google_compute_router.hub[0].name
  peer_ip_address = split("/", local.tunnel0_onprem_ip)[0]
  peer_asn        = var.onprem_router_asn
  interface       = google_compute_router_interface.hub_if0[0].name
}

resource "google_compute_router_interface" "hub_if1" {
  count      = var.simulate_hub_and_onpremises ? 1 : 0
  name       = "sim-hub-if1"
  project    = var.compute_project_id
  region     = var.compute_region
  router     = google_compute_router.hub[0].name
  ip_range   = local.tunnel1_hub_ip
  vpn_tunnel = google_compute_vpn_tunnel.hub_tunnel1[0].name
}

resource "google_compute_router_peer" "hub_peer1" {
  count           = var.simulate_hub_and_onpremises ? 1 : 0
  name            = "sim-hub-peer1"
  project         = var.compute_project_id
  region          = var.compute_region
  router          = google_compute_router.hub[0].name
  peer_ip_address = split("/", local.tunnel1_onprem_ip)[0]
  peer_asn        = var.onprem_router_asn
  interface       = google_compute_router_interface.hub_if1[0].name
}

# --- Router interfaces + BGP peers, on-prem side ---

resource "google_compute_router_interface" "onprem_if0" {
  count      = var.simulate_hub_and_onpremises ? 1 : 0
  name       = "sim-onprem-if0"
  project    = var.compute_project_id
  region     = var.compute_region
  router     = google_compute_router.onprem_sim[0].name
  ip_range   = local.tunnel0_onprem_ip
  vpn_tunnel = google_compute_vpn_tunnel.onprem_tunnel0[0].name
}

resource "google_compute_router_peer" "onprem_peer0" {
  count           = var.simulate_hub_and_onpremises ? 1 : 0
  name            = "sim-onprem-peer0"
  project         = var.compute_project_id
  region          = var.compute_region
  router          = google_compute_router.onprem_sim[0].name
  peer_ip_address = split("/", local.tunnel0_hub_ip)[0]
  peer_asn        = var.hub_router_asn
  interface       = google_compute_router_interface.onprem_if0[0].name
}

resource "google_compute_router_interface" "onprem_if1" {
  count      = var.simulate_hub_and_onpremises ? 1 : 0
  name       = "sim-onprem-if1"
  project    = var.compute_project_id
  region     = var.compute_region
  router     = google_compute_router.onprem_sim[0].name
  ip_range   = local.tunnel1_onprem_ip
  vpn_tunnel = google_compute_vpn_tunnel.onprem_tunnel1[0].name
}

resource "google_compute_router_peer" "onprem_peer1" {
  count           = var.simulate_hub_and_onpremises ? 1 : 0
  name            = "sim-onprem-peer1"
  project         = var.compute_project_id
  region          = var.compute_region
  router          = google_compute_router.onprem_sim[0].name
  peer_ip_address = split("/", local.tunnel1_hub_ip)[0]
  peer_asn        = var.hub_router_asn
  interface       = google_compute_router_interface.onprem_if1[0].name
}

################################################################################
# On-prem-side firewall: allow inbound from the hub and (transitively) the API
# spoke VPC, since routed traffic keeps its original source IP through the tunnel.
################################################################################

resource "google_compute_firewall" "onprem_allow_from_hub_and_spoke" {
  count     = var.simulate_hub_and_onpremises ? 1 : 0
  name      = "sim-onprem-allow-from-hub-and-spoke"
  project   = var.compute_project_id
  network   = google_compute_network.onprem_sim[0].id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.hub_vpc_cidr, var.api_vpc_cidr]

  allow {
    protocol = "tcp"
    ports    = ["443", "80", "8080"]
  }

  description = "Demo-scoped allow for the simulated Java app / RDBMS tier. Narrow ports/sources before treating this as a security reference."
}
variable "compute_project_id" {
  description = "Project ID hosting both simulated networks."
  type        = string
}

variable "compute_region" {
  description = "Region for both HA VPN gateways, routers, and subnets."
  type        = string
}

variable "api_vpc_cidr" {
  description = "API spoke VPC supernet. Allowed as a firewall source on the on-prem side, since traffic from the spoke is routed, not NAT'd, through the hub."
  type        = string
}

# --- Hub VPC (simulated) ---

variable "hub_vpc_cidr" {
  description = "Supernet for the simulated Hub VPC. Documentation-only; no resource takes this whole range."
  type        = string
  default     = "10.20.0.0/16"
}

variable "hub_subnet_cidr" {
  description = "Subnet carved from hub_vpc_cidr for the simulated hub's own resources."
  type        = string
  default     = "10.20.1.0/24"
}

variable "hub_router_asn" {
  description = "BGP ASN for the hub-side Cloud Router. Must differ from onprem_router_asn."
  type        = number
  default     = 64512
}

# --- On-premises (simulated) ---

variable "onpremises_cidr" {
  description = "Supernet assumed for real on-premises networks. Documentation-only; no resource takes this whole range."
  type        = string
  default     = "10.0.0.0/12"
}

variable "onprem_subnet_cidr" {
  description = "Subnet carved from onpremises_cidr for the simulated on-prem network's resources."
  type        = string
  default     = "10.0.1.0/24"
}

variable "onprem_router_asn" {
  description = "BGP ASN for the on-prem-side Cloud Router. Must differ from hub_router_asn."
  type        = number
  default     = 64513
}

# --- Toggle for swapping to a real Hub VPC later ---

variable "simulate_hub_and_onpremises" {
  description = "When true (default), this module creates both the Hub VPC and the on-premises VPC as GCP networks connected by a real HA VPN, for an end-to-end testable demo. When a real Hub VPC and on-prem gateway are confirmed, set false and stop calling this module for the hub network itself; a follow-up module should instead reference the real hub via data source and terminate the VPN against the real peer IPs."
  type        = bool
  default     = true
}

variable "enable_secret_manager" {
  description = "Store the generated VPN shared secret in Secret Manager. Matches the root enable_secret_manager toggle."
  type        = bool
  default     = true
}
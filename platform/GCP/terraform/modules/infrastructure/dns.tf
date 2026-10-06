# Cloud DNS resources for the Apigee Challenge
# Manages the public/private DNS record for api.example.com pointing to the Regional External ALB IP.

variable "enable_dns_registration" {
  description = "Enable Cloud DNS record creation for the public API endpoint."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Cloud DNS managed zone name."
  type        = string
  default     = "api-example-com"
}

variable "dns_domain" {
  description = "DNS domain name managed by the zone (must end with a dot)."
  type        = string
  default     = "api.example.com."
}

resource "google_dns_record_set" "api_endpoint" {
  count        = var.enable_dns_registration && local.has_valid_apigee_attachment ? 1 : 0
  project      = var.compute_project_id
  managed_zone = var.dns_zone_name
  name         = var.dns_domain
  type         = "A"
  ttl          = 300

  rrdatas = [
    google_compute_address.apigee_northbound_ip[0].address
  ]
}

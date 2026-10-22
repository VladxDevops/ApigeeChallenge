variable "compute_project_id" {
  description = "Compute project ID for the GCP project where observability resources will be created."
  type        = string
}

variable "compute_project_number" {
  description = "Compute project number for the GCP project."
  type        = string
  default     = ""
}

variable "compute_region" {
  description = "Compute region for the GCP resources (e.g. us-south1)."
  type        = string
  default     = "us-south1"
}

variable "dashboard_name" {
  description = "Display name for the Cloud Monitoring Latency & Observability Dashboard."
  type        = string
  default     = "Apigee End-to-End Latency & Observability Dashboard"
}

variable "enable_alerting" {
  description = "Whether to provision Cloud Monitoring alert policies."
  type        = bool
  default     = true
}

variable "create_alerts_when_metrics_ready" {
  description = "Gate creation of AlertPolicy resources until metrics/descriptors are available."
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Email address for alert policy notification channel. If empty, notification channel is skipped."
  type        = string
  default     = ""
}

variable "latency_threshold_ms" {
  description = "Threshold in milliseconds for backend latency alerts (corresponds to peak-hour latency bottleneck detection)."
  type        = number
  default     = 2000
}

variable "error_rate_threshold_percent" {
  description = "Threshold percentage for 5xx error rate alerts."
  type        = number
  default     = 5
}

variable "cloud_run_service_name" {
  description = "Name of the backend Cloud Run service to observe."
  type        = string
  default     = "api-backend-service"
}

variable "vpn_gateway_name" {
  description = "Name of the Cloud VPN gateway connecting to on-premises core."
  type        = string
  default     = "hub-to-onprem-vpn-gw"
}

variable "labels" {
  description = "Resource labels to attach to observability resources."
  type        = map(string)
  default = {
    environment = "dev"
    managed-by  = "terraform"
    domain      = "observability"
  }
}

###Cloud Run: 

variable "terraform_deployer_service_account_ldap" {
  description = "Service account name/ldap for the Terraform deployer."
  type        = string
}
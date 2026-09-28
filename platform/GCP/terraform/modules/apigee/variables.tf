# Compute Project ID, Number and region. 
variable "compute_project_id" {
  description = "Compute project ID for the GCP project where resources will be created."
  type        = string
}

variable "compute_project_number" {
  description = "Compute project number for the GCP project where resources will be created."
  type        = string
}


#Region and zone for the GCP resources: 
variable "compute_region" {
  description = "Compute region for the GCP resources."
  type        = string

}

variable "apigee_analytics_region" {
  description = "Apigee analytics region. Must be a region Apigee supports for analytics; it is not necessarily the same as the runtime region."
  type        = string
}

variable "apigee_billing_type" {
  description = "Apigee billing type: EVALUATION, SUBSCRIPTION or PAYG."
  type        = string
  default     = "EVALUATION"
}

variable "apigee_instance_name" {
  description = "Name of the Apigee runtime instance."
  type        = string
  default     = "apigee-instance-us-south1"
}

variable "apigee_disk_encryption_key_name" {
  description = "Optional CMEK for the instance disk. Only required for paid subscriptions."
  type        = string
  default     = null
}

variable "northbound_consumer_project_ids" {
  description = "Project IDs allowed to create northbound PSC connections to the Apigee instance (the project that owns the external ALB's PSC NEG)."
  type        = list(string)
}

variable "apigee_environment_name" {
  description = "Apigee environment name."
  type        = string
  default     = "dev"
}

variable "apigee_envgroup_name" {
  description = "Apigee environment group name."
  type        = string
  default     = "dev-group"
}

variable "apigee_envgroup_hostnames" {
  description = "Hostnames routed to the environment group. Must match the hostname clients send through the external ALB."
  type        = list(string)
}

variable "southbound_service_attachment_id" {
  description = "ID of the producer-side service attachment (google_compute_service_attachment.api_psc) that Apigee reaches southbound."
  type        = string
}

variable "southbound_endpoint_attachment_id" {
  description = "ID of the Apigee endpoint attachment (lowercase letters, digits, hyphens)."
  type        = string
  default     = "cloudrun-backend"
}
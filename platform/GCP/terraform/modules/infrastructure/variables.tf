variable "compute_project_id" {
  description = "Compute project ID for the GCP project where resources will be created."
  type        = string
}

variable "compute_project_number" {
  description = "Compute project number for the GCP project where resources will be created."
  type        = string
}

#Networkign: 
#Region and zone for the GCP resources: 
variable "compute_region" {
  description = "Compute region for the GCP resources."
  type        = string

}

variable "api_spoke_network_id" {
  description = "ID of the API spoke VPC network."
  type        = string
}

#Terraform remote state bucket name:
variable "terraform_remote_state_bucket_name" {
  description = "Name of the GCS bucket for Terraform remote state."
  type        = string
}


#Terraform deployer service account:
variable "terraform_deployer_service_account" {
  description = "Service account email for the Terraform deployer."
  type        = string
}

# Variables for networking and rightsized subnets:
variable "api_vpc_cidr" {
  description = "Documentation-only supernet for the API spoke VPC."
  type        = string
}

variable "api_private_subnet_cidr" {
  description = "Primary private subnet for API/backend resources in us-south1 (lean /28 allocation, 16 IPs total, 12 usable IPs)."
  type        = string
}

variable "proxy_only_subnet_cidr" {
  description = "Regional managed proxy-only subnet for Envoy-based load balancers (GCP enforced minimum /26, 64 IPs total, 60 usable proxy IPs)."
  type        = string
}

variable "psc_nat_subnet_cidr" {
  description = "Private Service Connect NAT subnet for published services (GCP minimum /29, 8 IPs total, 4 usable NAT IPs)."
  type        = string
}

# Cloud Run backend variables
variable "cloud_run_service_name" {
  description = "Name of the Cloud Run backend service."
  type        = string
  default     = "rocketcode-demo-backend"
}

variable "cloud_run_invoker_members" {
  type        = list(string)
  description = "List of IAM members (e.g. ['serviceAccount:apigee-sa@...']) authorized to invoke the Cloud Run service."
  default     = []
}

variable "cloud_run_image" {
  description = "Container image for the Cloud Run backend service."
  type        = string
  default     = "gcr.io/cloudrun/hello"
}

variable "cloud_run_container_port" {
  description = "Container port exposed by the backend application."
  type        = number
  default     = 8080
}

variable "cloud_run_service_account_email" {
  description = "Service account email used by the Cloud Run runtime. Leave empty to use the default compute service account."
  type        = string
  default     = ""
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances for the service."
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances for the service."
  type        = number
  default     = 2
}

variable "cloud_run_cpu_limit" {
  description = "CPU limit for the Cloud Run container."
  type        = string
  default     = "1000m"
}

variable "cloud_run_memory_limit" {
  description = "Memory limit for the Cloud Run container."
  type        = string
  default     = "512Mi"
}

# Artifact Registry variables
variable "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID / name for container images."
  type        = string
  default     = "rocketcode-demo-repo"
}

variable "artifact_registry_format" {
  description = "Repository format: DOCKER or other OCI-compatible format."
  type        = string
  default     = "DOCKER"
}

variable "artifact_registry_cleanup_enabled" {
  description = "Enable automatic cleanup of unused images."
  type        = bool
  default     = false
}

### Variables from Private Service Connect (PSC) module:

#Deprecated variable "api_backend_port": 
#variable "api_backend_port" {
#  type        = number
#  description = "Port the backend service listens on behind the ILB."
#}


variable "apigee_consumer_project_id" {
  type        = string
  description = "Project ID or number of the Apigee (or other) consumer allowed to connect via PSC."
}

variable "apigee_northbound_service_attachment" {
  type        = string
  description = "Service attachment URI Apigee provides for northbound PSC connectivity."
}

variable "tls_private_key" {
  type      = string
  sensitive = true
}

variable "tls_certificate" {
  type = string
}

variable "cloud_run_vpc_connector_cidr" {
  description = "CIDR used by the Cloud Run VPC connector for private egress. Must not overlap the API spoke subnets."
  type        = string
  default     = "10.80.0.128/28"
}
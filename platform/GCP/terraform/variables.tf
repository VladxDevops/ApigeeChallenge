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

# Variables for VPC and rightsized subnets:
variable "api_vpc_cidr" {
  description = "Documentation-only supernet for the API spoke VPC."
  type        = string
  default     = "10.80.0.0/16"
}

variable "api_private_subnet_cidr" {
  description = "Primary private subnet for API/backend resources in us-south1 (lean /28 allocation, 16 IPs total, 12 usable IPs)."
  type        = string
  default     = "10.80.0.0/28"
}

variable "proxy_only_subnet_cidr" {
  description = "Regional managed proxy-only subnet for Envoy-based load balancers (GCP enforced minimum /26, 64 IPs total, 60 usable proxy IPs)."
  type        = string
  default     = "10.80.0.64/26"
}

variable "psc_nat_subnet_cidr" {
  description = "Private Service Connect NAT subnet for published services (GCP minimum /29, 8 IPs total, 4 usable NAT IPs)."
  type        = string
  default     = "10.80.0.16/29"
}

# Assumed existing network ranges (from addressing plan - security module)
variable "hub_vpc_cidr" {
  description = "CIDR range of the existing Hub VPC (assumed: 10.20.0.0/16 per addressing plan)."
  type        = string
  default     = "10.20.0.0/16"
}

variable "onpremises_cidr" {
  description = "CIDR range of on-premises networks (assumed: 10.0.0.0/12 per addressing plan)."
  type        = string
  default     = "10.0.0.0/12"
}

# Secret Manager variables
variable "enable_secret_manager" {
  description = "Enable Secret Manager resources for storing sensitive application configuration."
  type        = bool
  default     = true
}

variable "secret_api_key" {
  description = "Placeholder API key secret value (replace in actual deployment)."
  type        = string
  default     = "PLACEHOLDER_API_KEY_REPLACE_ME"
  sensitive   = true
}

variable "secret_db_password" {
  description = "Placeholder database password secret value (replace in actual deployment)."
  type        = string
  default     = "PLACEHOLDER_DB_PASSWORD_REPLACE_ME"
  sensitive   = true
}

variable "secret_oauth_client_secret" {
  description = "Placeholder OAuth client secret value (replace in actual deployment)."
  type        = string
  default     = "PLACEHOLDER_OAUTH_SECRET_REPLACE_ME"
  sensitive   = true
}

variable "secret_jwt_signing_key" {
  description = "Placeholder JWT signing key secret value (replace in actual deployment)."
  type        = string
  default     = "PLACEHOLDER_JWT_KEY_REPLACE_ME"
  sensitive   = true
}


### Variables from Private Service Connect (PSC) module: 

# Deprecated variable "api_backend_port": 
#variable "api_backend_port" {
#  type        = number
#  description = "Port the backend service listens on behind the ILB."
#}

variable "cloud_run_service_name" {
  type        = string
  description = "Name of the Cloud Run service acting as the backend."
}

#variable "apigee_consumer_project_id" {
#  type        = string
#  description = "Project ID or number of the Apigee (or other) consumer allowed to connect via PSC."
#}

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


### Apigee module variables:

variable "apigee_analytics_region" {
  description = "Apigee analytics region. Verify it against the regions Apigee supports for analytics."
  type        = string
}

variable "apigee_billing_type" {
  description = "Apigee billing type: EVALUATION, SUBSCRIPTION or PAYG."
  type        = string
  default     = "EVALUATION"
}

variable "apigee_envgroup_hostnames" {
  description = "Hostnames routed to the Apigee environment group (must match what clients send through the external ALB)."
  type        = list(string)
  default     = ["api.example.com"]
}
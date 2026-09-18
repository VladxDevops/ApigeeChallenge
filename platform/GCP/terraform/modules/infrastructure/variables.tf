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

#Variables for networking: 
variable "api_vpc_cidr" {
  description = "Documentation-only supernet for the API spoke VPC."
  type        = string
}

variable "api_private_subnet_cidr" {
  description = "Primary private subnet for API/backend resources in us-south1."
  type        = string
}

variable "proxy_only_subnet_cidr" {
  description = "Regional managed proxy-only subnet for Envoy-based load balancers."
  type        = string
}

variable "psc_nat_subnet_cidr" {
  description = "Private Service Connect NAT subnet for published services."
  type        = string
}

###

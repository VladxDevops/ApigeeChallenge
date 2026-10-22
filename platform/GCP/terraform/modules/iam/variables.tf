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

# Terraform Service account name/ldap
variable "terraform_deployer_service_account_ldap" {
  description = "Service account name/ldap for the Terraform deployer."
  type        = string
}

# Cloud Run: 

## Cloud Run Service Account name: 
variable "cloud_run_service_account_ldap" {
  description = "LDAP name for the Cloud Run service account to be created in the IAM module. It will be used by the Cloud Run service for execution."
  type        = string
}
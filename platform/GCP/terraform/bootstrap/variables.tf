variable "compute_project_id" {
  description = "GCP Project B ID"
  type        = string
}

variable "compute_region" {
  description = "Region for the Google provider"
  type        = string
}

variable "terraform_remote_state_bucket_name" {
  description = "Globally unique Terraform state bucket name"
  type        = string
}
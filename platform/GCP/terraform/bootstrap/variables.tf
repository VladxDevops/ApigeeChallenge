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

variable "github_repository_owner" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_repository_name" {
  description = "GitHub repository name trusted by the WIF provider."
  type        = string
}

variable "github_deployment_branch" {
  description = "Full branch ref trusted for initial DEV deployments."
  type        = string
}

variable "wif_pool_id" {
  description = "Workload Identity pool ID for GitHub Actions."
  type        = string
  default     = "github-actions-dev"
}

variable "wif_provider_id" {
  description = "OIDC provider ID for GitHub Actions."
  type        = string
  default     = "github-actions-dev-provider"
}

variable "terraform_deployer_service_account_email" {
  description = "Existing DEV Terraform deployer service account to bind to GitHub Actions WIF."
  type        = string
}
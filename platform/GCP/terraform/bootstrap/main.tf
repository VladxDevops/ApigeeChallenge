terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.26.0"
    }
  }
}

provider "google" {
  project = var.compute_project_id
  region  = var.compute_region
}


resource "google_storage_bucket" "terraform_state_backend_apigeechallenge" {
  name                        = var.terraform_remote_state_bucket_name
  location                    = var.compute_region
  uniform_bucket_level_access = true
  force_destroy               = false
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true #Preventing delete of the bucket to avoid accidental loss of Terraform state files.
  }
}

# GitHub Actions OIDC APIs required before WIF authentication.
resource "google_project_service" "sts" {
  project            = var.compute_project_id
  service            = "sts.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_credentials" {
  project            = var.compute_project_id
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github_actions" {
  project                   = var.compute_project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions DEV"
  description               = "Federates the githubuser/ApigeeChallenge GitHub repository with GCP for DEV automation."
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  project                            = var.compute_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "GitHub Actions DEV provider"
  description                        = "Restricts GitHub OIDC to Build-DEV deployments in the selected repository."

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "attribute.repository == \"${var.github_repository_owner}/${var.github_repository_name}\" && attribute.ref == \"${var.github_deployment_branch}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_actions_deployer" {
  service_account_id = "projects/${var.compute_project_id}/serviceAccounts/${var.terraform_deployer_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_repository_owner}/${var.github_repository_name}"

  depends_on = [
    google_iam_workload_identity_pool_provider.github_actions
  ]
}

output "github_actions_workload_identity_provider" {
  description = "Full resource name to configure in GitHub Actions."
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "github_actions_deployer_service_account" {
  description = "GCP service account impersonated by GitHub Actions."
  value       = var.terraform_deployer_service_account_email
}
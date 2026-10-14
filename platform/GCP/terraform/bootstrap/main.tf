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
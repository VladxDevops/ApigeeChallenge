terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.1.0"
    }
  }
}

#GCp provider configuration
provider "google" {
  project = var.compute_project_id
  region  = var.compute_region
}

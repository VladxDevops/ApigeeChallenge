terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.26.0, < 8.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

#GCp provider configuration
provider "google" {
  project = var.compute_project_id
  region  = var.compute_region
}

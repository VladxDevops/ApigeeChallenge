#Create GCS Bucket for Terraform remote backend state management. The bucket name is "terraform_state_backend_rocket" and the prefix for the state files is "terraform/state". The required Terraform version is set to ">= 1.5.0".

resource "google_storage_bucket" "terraform_state_backend_rocket" {
  name                     = var.terraform_remote_state_bucket_name
  location                 = var.compute_region
  force_destroy            = false
  public_access_prevention = "enforced"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true #Preventing delete of the bucket to avoid accidental loss of Terraform state files.
  }
}

###Terraform remote backend configuration for GCP

terraform {
  backend "gcs" {
    bucket = "terraform_state_backend_rocket"
    prefix = "terraform/state"
  }

  required_version = ">= 1.5.0"
}

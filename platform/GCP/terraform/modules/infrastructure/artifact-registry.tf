# Minimal Artifact Registry repository for demo container images.
# This stores the OCI-compatible container images used by the Cloud Run backend service.
resource "google_artifact_registry_repository" "helo_apigee_repo" {
  location      = var.compute_region
  repository_id = var.artifact_registry_repository_id
  description   = "Artifact Registry for rocketcode demo application images"
  format        = var.artifact_registry_format
  project       = var.compute_project_id

  lifecycle {
    ignore_changes = [labels]
  }
}

output "artifact_registry_repository_name" {
  description = "Full name of the Artifact Registry repository."
  value       = google_artifact_registry_repository.helo_apigee_repo.name
}

output "artifact_registry_repository_url" {
  description = "Repository URL for pushing/pulling container images."
  value       = "${var.compute_region}-docker.pkg.dev/${var.compute_project_id}/${var.artifact_registry_repository_id}"
}

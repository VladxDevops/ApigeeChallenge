# Cloud Build configuration and container image compilation triggers.
# Integrates source code in APPS/hello-backend with Artifact Registry and Cloud Run.

locals {
  target_image_uri = "${var.compute_region}-docker.pkg.dev/${var.compute_project_id}/${var.artifact_registry_repository_id}/${var.cloud_run_service_name}:latest"
}

# Terraform build step trigger invoking gcloud builds submit during deployment.
# This is intentionally a local build step, not a repo-backed Cloud Build trigger,
# because the repo is not configured as a Cloud Source Repository in this exercise.
resource "terraform_data" "build_hello_backend" {
  input = local.target_image_uri

  provisioner "local-exec" {
    command     = "SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo local-$(date +%s)) && gcloud builds submit --config=APPS/hello-backend/cloudbuild.yaml --substitutions=_REGION=${var.compute_region},_REPOSITORY=${var.artifact_registry_repository_id},_SERVICE_NAME=${var.cloud_run_service_name},_SHORT_SHA=$SHORT_SHA APPS/hello-backend"
    working_dir = "${path.module}/../../../../../"
  }

  depends_on = [google_artifact_registry_repository.helo_apigee_repo]
}

output "built_container_image_uri" {
  description = "URI of the container image built by Cloud Build and stored in Artifact Registry."
  value       = local.target_image_uri
}

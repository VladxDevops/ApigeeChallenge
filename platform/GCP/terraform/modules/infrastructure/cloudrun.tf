# Minimal private backend service for the demo API platform.
# This intentionally avoids public ingress and keeps the service isolated behind the
# API management and private connectivity layers.
resource "google_cloud_run_v2_service" "api_backend" {
  name     = var.cloud_run_service_name
  location = var.compute_region
  project  = var.compute_project_id

  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = var.cloud_run_service_account_email != "" ? var.cloud_run_service_account_email : null

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = var.cloud_run_image

      ports {
        container_port = var.cloud_run_container_port
      }

      #env {
      # name  = "PORT"
      #value = tostring(var.cloud_run_container_port)
      #}

      env {
        name  = "APP_ENV"
        value = "dev"
      }

      resources {
        limits = {
          cpu    = var.cloud_run_cpu_limit
          memory = var.cloud_run_memory_limit
        }
      }
    }
  }
}

output "cloud_run_service_name" {
  description = "Cloud Run service name for the private API backend."
  value       = google_cloud_run_v2_service.api_backend.name
}

output "cloud_run_service_url" {
  description = "Internal Cloud Run service URL when available."
  value       = google_cloud_run_v2_service.api_backend.uri
}

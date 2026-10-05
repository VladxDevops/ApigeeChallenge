# Minimal private backend service for the demo API platform.
# This intentionally avoids public ingress and keeps the service isolated behind the
# API management and private connectivity layers.

resource "google_vpc_access_connector" "cloud_run_connector" {
  name          = "api-cloudrun-connector"
  project       = var.compute_project_id
  region        = var.compute_region
  network       = google_compute_network.api_spoke.id
  ip_cidr_range = var.cloud_run_vpc_connector_cidr
  min_instances = "2"
  max_instances = "3"

  depends_on = [google_compute_subnetwork.api_private]
}

resource "google_cloud_run_v2_service" "api_backend" {
  name     = var.cloud_run_service_name
  location = var.compute_region
  project  = var.compute_project_id

  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.cloud_run_service_account_email != "" ? var.cloud_run_service_account_email : null

    vpc_access {
      connector = google_vpc_access_connector.cloud_run_connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = var.cloud_run_image

      ports {
        container_port = var.cloud_run_container_port
      }

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

  depends_on = [
    google_artifact_registry_repository.helo_apigee_repo,
    terraform_data.build_hello_backend,
    google_vpc_access_connector.cloud_run_connector
  ]
}

output "cloud_run_service_name" {
  description = "Cloud Run service name for the private API backend."
  value       = google_cloud_run_v2_service.api_backend.name
}

output "cloud_run_service_url" {
  description = "Internal Cloud Run service URL when available."
  value       = google_cloud_run_v2_service.api_backend.uri
}

output "cloud_run_connector_id" {
  description = "VPC Access connector used for private serverless egress from Cloud Run."
  value       = google_vpc_access_connector.cloud_run_connector.id
}

################################################################################
# Secret Manager Resources
# Purpose: Secure storage for application secrets, credentials, and sensitive
#          configuration required by the API platform and backend services.
#          All secrets use versioning and are accessible only to authorized
#          service accounts through Secret Manager IAM bindings.
################################################################################

# API Key secret
resource "google_secret_manager_secret" "api_key" {
  count     = var.enable_secret_manager ? 1 : 0
  project   = var.compute_project_id
  secret_id = "api-key-dev"

  labels = merge(
    var.common_labels,
    {
      secret_type = "api-key"
      environment = var.environment
    }
  )

  replication {
    user_managed {
      replicas {
        location = var.compute_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "api_key" {
  count       = var.enable_secret_manager ? 1 : 0
  secret      = google_secret_manager_secret.api_key[0].id
  secret_data = var.secret_api_key
}

# Database password secret
resource "google_secret_manager_secret" "db_password" {
  count     = var.enable_secret_manager ? 1 : 0
  project   = var.compute_project_id
  secret_id = "db-password-dev"

  labels = merge(
    var.common_labels,
    {
      secret_type = "database"
      environment = var.environment
    }
  )

  replication {
    user_managed {
      replicas {
        location = var.compute_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  count       = var.enable_secret_manager ? 1 : 0
  secret      = google_secret_manager_secret.db_password[0].id
  secret_data = var.secret_db_password
}

# OAuth client secret
resource "google_secret_manager_secret" "oauth_client_secret" {
  count     = var.enable_secret_manager ? 1 : 0
  project   = var.compute_project_id
  secret_id = "oauth-client-secret-dev"

  labels = merge(
    var.common_labels,
    {
      secret_type = "oauth"
      environment = var.environment
    }
  )

  replication {
    user_managed {
      replicas {
        location = var.compute_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "oauth_client_secret" {
  count       = var.enable_secret_manager ? 1 : 0
  secret      = google_secret_manager_secret.oauth_client_secret[0].id
  secret_data = var.secret_oauth_client_secret
}

# JWT signing key secret
resource "google_secret_manager_secret" "jwt_signing_key" {
  count     = var.enable_secret_manager ? 1 : 0
  project   = var.compute_project_id
  secret_id = "jwt-signing-key-dev"

  labels = merge(
    var.common_labels,
    {
      secret_type = "jwt"
      environment = var.environment
    }
  )

  replication {
    user_managed {
      replicas {
        location = var.compute_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "jwt_signing_key" {
  count       = var.enable_secret_manager ? 1 : 0
  secret      = google_secret_manager_secret.jwt_signing_key[0].id
  secret_data = var.secret_jwt_signing_key
}

# Allow Cloud Run service account to access all secrets
resource "google_secret_manager_secret_iam_member" "cloud_run_api_key_accessor" {
  count     = var.enable_secret_manager && var.create_cloud_run_service_account ? 1 : 0
  secret_id = google_secret_manager_secret.api_key[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa[0].email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_db_password_accessor" {
  count     = var.enable_secret_manager && var.create_cloud_run_service_account ? 1 : 0
  secret_id = google_secret_manager_secret.db_password[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa[0].email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_oauth_accessor" {
  count     = var.enable_secret_manager && var.create_cloud_run_service_account ? 1 : 0
  secret_id = google_secret_manager_secret.oauth_client_secret[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa[0].email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_jwt_accessor" {
  count     = var.enable_secret_manager && var.create_cloud_run_service_account ? 1 : 0
  secret_id = google_secret_manager_secret.jwt_signing_key[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa[0].email}"
}



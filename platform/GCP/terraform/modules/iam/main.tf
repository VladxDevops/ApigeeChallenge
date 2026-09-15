

#Terraform service account roles: 

# Terraform Deployer Service Account Roles:

resource "google_project_iam_member" "terraform_sa_service_usage_admin" {
  project = var.compute_project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_workload_identity_admin" {
  project = var.compute_project_id
  role    = "roles/iam.workloadIdentityPoolAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_google_cloud_deploy_admin" {
  project = var.compute_project_id
  role    = "roles/clouddeploy.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_cloud_deploy_releaser" {
  project = var.compute_project_id
  role    = "roles/clouddeploy.releaser"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_artifact_registry_admin" {
  project = var.compute_project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_artifact_registry_writer" {
  project = var.compute_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_cloud_build_editor" {
  project = var.compute_project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_cloud_run_admin" {
  project = var.compute_project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_cloud_run_invoker" {
  project = var.compute_project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_cloud_sql_admin" {
  project = var.compute_project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_compute_network_admin" {
  project = var.compute_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_iam_service_account_creator" {
  project = var.compute_project_id
  role    = "roles/iam.serviceAccountCreator"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_infrastructure_admin" {
  project = var.compute_project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_project_iam_admin" {
  project = var.compute_project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_secret_manager_admin" {
  project = var.compute_project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_secret_manager_accessor" {
  project = var.compute_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_iam_security_admin" {
  project = var.compute_project_id
  role    = "roles/iam.securityAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_serverless_vpc_access_admin" {
  project = var.compute_project_id
  role    = "roles/vpcaccess.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_iam_service_account_user" {
  project = var.compute_project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_service_usage_consumer" {
  project = var.compute_project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_storage_admin" {
  project = var.compute_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_cloudsql_admin" {
  project = var.compute_project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_remote_project_iam_admin" {
  project = var.remote_terraform_state_gcp_project
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_remote_secret_viewer" {
  project = var.remote_terraform_state_gcp_project
  role    = "roles/secretmanager.viewer"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_remote_secret_accessor" {
  project = var.remote_terraform_state_gcp_project
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_logging_writer" {
  project = var.compute_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}



# Terraform Deployer Service Account declaration
resource "google_service_account" "terraform_deployer" {
  account_id   = var.terraform_deployer_service_account_name
  display_name = "DEV Terraform Deployer Service Account"
  project      = var.compute_project_id
  description  = "Dedicated service account used by Terraform for GCP resource provisioning."
}

# Terraform Deployer Service Account Roles:

resource "google_project_iam_member" "terraform_sa_project_iam_admin" {
  project = var.compute_project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_iam_security_admin" {
  project = var.compute_project_id
  role    = "roles/iam.securityAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_service_usage_admin" {
  project = var.compute_project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_iam_service_account_creator" {
  project = var.compute_project_id
  role    = "roles/iam.serviceAccountCreator"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_compute_network_admin" {
  project = var.compute_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_infrastructure_admin" {
  project = var.compute_project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_serverless_vpc_access_admin" {
  project = var.compute_project_id
  role    = "roles/vpcaccess.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_compute_security_admin" {
  project = var.compute_project_id
  role    = "roles/compute.securityAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_iam_service_account_user" {
  project = var.compute_project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_storage_admin" {
  project = var.compute_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

#Roles that can be added by itself: 
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

resource "google_project_iam_member" "terraform_sa_compute_load_balancer_admin" {
  project = var.compute_project_id
  role    = "roles/compute.loadBalancerAdmin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_service_usage_consumer" {
  project = var.compute_project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_monitoring_admin" {
  project = var.compute_project_id
  role    = "roles/monitoring.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_logging_admin" {
  project = var.compute_project_id
  role    = "roles/logging.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

#Devops Role: 
resource "google_project_iam_member" "terraform_sa_devops_role" {
  project = var.compute_project_id
  role    = "roles/iam.devOps"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}

resource "google_project_iam_member" "terraform_sa_apigee_admin_role" {
  project = var.compute_project_id
  role    = "roles/apigee.admin"
  member  = "serviceAccount:${var.terraform_deployer_service_account}"
}
###End of Roles for terraform deployer service account


### Cloud Run: 
# Cloud Run Service Account declaration: 
resource "google_service_account" "cloud_run_service_account" {
  account_id   = var.cloudrun_service_account_ldap
  display_name = "Cloud Run Service Account"
  project      = var.compute_project_id
  description  = "Dedicated service account used by Cloud Run for execution."
}

## Roles for the Cloud Run Service Account:

# Cloud Run Invoker Role for the Cloud Run Service Account:
resource "google_project_iam_member" "cloud_run_sa_cloud_run_invoker" {
  project = var.compute_project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.cloud_run_service_account.email}" 
  depends_on = [ google_service_account.cloud_run_service_account ]
}

# Cloud Run Service Account Roles for Artifact Registry reader: 
resource "google_project_iam_member" "cloud_run_sa_artifact_registry_reader" {
  project = var.compute_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_service_account.email}" 
  depends_on = [ google_service_account.cloud_run_service_account ]
}

# Cloud Run Service Account Roles for Secret Manager secret accessor:
#resource "google_project_iam_member" "cloud_run_sa_secret_manager_accessor" {
#  project = var.compute_project_id
#  role    = "roles/secretmanager.secretAccessor"
#  member  = "serviceAccount:${google_service_account.cloud_run_service_account.email}"
#  depends_on = [ google_service_account.cloud_run_service_account ]
#}


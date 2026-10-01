### Enable Apigee GCP Service: 
resource "google_project_service" "apigee" {
  project = var.compute_project_id
  service = "apigee.googleapis.com"
}

### Apigee:
# Apigee organization - non-VPC-peering. No authorized_network and no customer CIDR:
# Apigee stays in its Google-managed tenant project and is reached only through PSC.
resource "google_apigee_organization" "org" {
  project_id          = var.compute_project_id
  analytics_region    = var.compute_region
  billing_type        = var.apigee_billing_type
  runtime_type        = "CLOUD"
  disable_vpc_peering = true
  description         = "Apigee organization (non-VPC-peering, PSC connectivity)."
}

### Apiegee service account:

resource "google_service_account" "apigee-admin-sa" {
  account_id   = var.apigee_admin_service_account_name_dev
  display_name = "Apigee Admin Service Account Dev"
  project      = var.compute_project_id
  description  = "Dedicated service account used by Apigee for administration."
}

resource "google_project_iam_member" "apigee-admin-sa" {
  project = var.compute_project_id
  role    = "roles/apigee.admin"
  member  = "serviceAccount:${var.apigee_admin_service_account_name_dev}@${var.compute_project_id}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "apigee_sa_cloud_run_invoker" {
  project = var.compute_project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.apigee-admin-sa.email}"
}

# Runtime instance. consumer_accept_list controls which projects may attach
# a northbound PSC NEG to this instance's service attachment.
resource "google_apigee_instance" "apigee_instance" {
  name                     = var.apigee_instance_name
  location                 = var.compute_region
  org_id                   = google_apigee_organization.org.id
  description              = "Apigee runtime instance."
  consumer_accept_list     = var.northbound_consumer_project_ids
  disk_encryption_key_name = var.apigee_disk_encryption_key_name
}

resource "google_apigee_environment" "env" {
  org_id       = google_apigee_organization.org.id
  name         = var.apigee_environment_name
  display_name = var.apigee_environment_name
  description  = "Apigee environment."
}

resource "google_apigee_instance_attachment" "env_to_instance" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.env.name
}

resource "google_apigee_envgroup" "envgroup" {
  org_id    = google_apigee_organization.org.id
  name      = var.apigee_envgroup_name
  hostnames = var.apigee_envgroup_hostnames
}

resource "google_apigee_envgroup_attachment" "env_to_envgroup" {
  envgroup_id = google_apigee_envgroup.envgroup.id
  environment = google_apigee_environment.env.name
}

# Southbound PSC: Apigee endpoint attachment pointing at the producer service attachment
# published from the API spoke VPC (ILB -> serverless NEG -> Cloud Run).
resource "google_apigee_endpoint_attachment" "cloud_run_backend" {
  org_id                 = google_apigee_organization.org.id
  endpoint_attachment_id = var.southbound_endpoint_attachment_id
  location               = var.compute_region
  service_attachment     = var.southbound_service_attachment_id

  depends_on = [google_apigee_instance.apigee_instance]
}
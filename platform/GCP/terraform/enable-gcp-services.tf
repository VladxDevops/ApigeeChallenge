module "enable-gcp-services" {
  source = "./modules/enable-gcp-services"

  compute_project_id                 = var.compute_project_id
  compute_project_number             = var.compute_project_number
  compute_region                     = var.compute_region
  terraform_remote_state_bucket_name = var.terraform_remote_state_bucket_name
}
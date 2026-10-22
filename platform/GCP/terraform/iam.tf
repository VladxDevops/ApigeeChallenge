module "iam" {
  source = "./modules/iam"

  compute_project_id                 = var.compute_project_id
  compute_project_number             = var.compute_project_number
  compute_region                     = var.compute_region
  terraform_deployer_service_account = var.terraform_deployer_service_account
  terraform_remote_state_bucket_name = var.terraform_remote_state_bucket_name
  terraform_deployer_service_account_ldap = var.terraform_deployer_service_account_ldap
  cloud_run_service_account_ldap = var.cloud_run_service_account_ldap
}
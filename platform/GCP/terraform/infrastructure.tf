module "infrastructure" {
  source = "./modules/infrastructure"

  compute_project_id                 = var.compute_project_id
  compute_project_number             = var.compute_project_number
  compute_region                     = var.compute_region
  terraform_remote_state_bucket_name = var.terraform_remote_state_bucket_name
  terraform_deployer_service_account = var.terraform_deployer_service_account
  api_vpc_cidr                       = var.api_vpc_cidr
  api_private_subnet_cidr            = var.api_private_subnet_cidr
  proxy_only_subnet_cidr             = var.proxy_only_subnet_cidr
  psc_nat_subnet_cidr                = var.psc_nat_subnet_cidr
}

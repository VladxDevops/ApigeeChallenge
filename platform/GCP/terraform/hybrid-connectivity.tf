module "hybrid_connectivity" {
  source = "./modules/hybrid-connectivity"

  compute_project_id = var.compute_project_id
  compute_region     = var.compute_region
  api_vpc_cidr       = var.api_vpc_cidr
  hub_vpc_cidr       = var.hub_vpc_cidr
  onpremises_cidr    = var.onpremises_cidr

  enable_secret_manager = var.enable_secret_manager
}
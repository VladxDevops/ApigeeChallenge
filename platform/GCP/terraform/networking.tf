module "networking" {
  source = "./modules/networking"

  compute_project_id                        = var.compute_project_id
  compute_project_number                    = var.compute_project_number
  compute_region = var.compute_region
}
module "apigee" {
    source = "./modules/apigee"
  
  compute_project_id                 = var.compute_project_id
  compute_project_number             = var.compute_project_number
  compute_region                     = var.compute_region
  #consumer_project_id                  = var.compute_project_id
  apigee_analytics_region = var.apigee_analytics_region
  apigee_billing_type     = var.apigee_billing_type

  # Northbound: the project that owns the external ALB's PSC NEG.
  northbound_consumer_project_ids = [var.compute_project_id]
  apigee_envgroup_hostnames       = var.apigee_envgroup_hostnames

  # Southbound: the service attachment the infrastructure module publishes.
  southbound_service_attachment_id = module.infrastructure.api_psc_service_attachment_id

}
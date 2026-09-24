output "terraform_deployer_sa_email" {
  description = "Email address of the Terraform deployer service account."
  value       = google_service_account.terraform_deployer.email
}

output "terraform_deployer_sa_id" {
  description = "Resource ID of the Terraform deployer service account."
  value       = google_service_account.terraform_deployer.id
}

output "terraform_deployer_sa_name" {
  description = "Fully qualified name of the Terraform deployer service account."
  value       = google_service_account.terraform_deployer.name
}

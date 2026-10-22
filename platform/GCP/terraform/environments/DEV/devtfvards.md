compute_project_id     = "Value_removed"
compute_project_number = "Value_removed"

#Terraform: 
terraform_deployer_service_account = "Value_removed"
#Remote Storage Bucket: 
terraform_remote_state_bucket_name = "Value_removed"

#Region and zone: 
compute_region = "us-south1"


# Networking variables
api_vpc_cidr            = "10.80.0.0/16"
api_private_subnet_cidr = "10.80.1.0/28"
proxy_only_subnet_cidr  = "10.80.2.0/26"
psc_nat_subnet_cidr     = "10.80.3.0/29"


# Cloud Run backend service configuration
cloud_run_service_name          = "rocketcode-demo-backend"
cloud_run_image                 = "gcr.io/cloudrun/hello" #Repace with your actual container image. 
cloud_run_container_port        = 8080
cloud_run_service_account_email = "" # Leave empty to use default compute service account
cloud_run_min_instances         = 0
cloud_run_max_instances         = 1
cloud_run_cpu_limit             = "1000m"
cloud_run_memory_limit          = "512Mi"


# Artifact Registry configuration
artifact_registry_repository_id   = "Value_removed"
artifact_registry_format          = "DOCKER"
artifact_registry_cleanup_enabled = false


# Secret Manager configuration - replace placeholders with actual secure values
enable_secret_manager      = true
secret_api_key             = "PLACEHOLDER_API_KEY_REPLACE_ME_WITH_SECURE_VALUE"
secret_db_password         = "PLACEHOLDER_DB_PASSWORD_REPLACE_ME_WITH_SECURE_VALUE"
secret_oauth_client_secret = "PLACEHOLDER_OAUTH_SECRET_REPLACE_ME_WITH_SECURE_VALUE"
secret_jwt_signing_key     = "PLACEHOLDER_JWT_KEY_REPLACE_ME_WITH_SECURE_VALUE"


### Variables from Pivate Service Connect (PSC) module

#Deprecated variable "api_backend_port":
#api_backend_port = 8080  # Port on which the backend service listens: 
apigee_northbound_service_attachment = "" # Set to actual Apigee service attachment URI once Apigee instance is provisioned
tls_private_key                      = "" # Leave empty to auto-generate dev self-signed TLS cert, or supply custom PEM private key
tls_certificate                      = "" # Leave empty to auto-generate dev self-signed TLS cert, or supply custom PEM certificate


### Apigee
apigee_analytics_region   = "VERIFY_SUPPORTED_ANALYTICS_REGION"
apigee_billing_type       = "EVALUATION"
apigee_envgroup_hostnames = ["api.example.com"]

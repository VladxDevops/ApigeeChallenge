I ran terraform init again.

Then I tried terraform apply the infra module and got the following errors:

"Error: Error when reading or editing RegionSecurityPolicy: googleapi: Error 400: The security_policy resource 'api-armor-policy' is already being used by '1 references', resourceInUseByAnotherResource
│
│
╵
╷
│ Error: Error updating ServiceAttachment "projects/rocketcodeapigee/regions/us-south1/serviceAttachments/api-psc-service-attachment": googleapi: Error 400: Invalid value for field 'resource.connectionPreference': 'ACCEPT_AUTOMATIC'. Incorrect combination of connection preference with accept and/or reject list, invalid
│
│   with module.infrastructure.google_compute_service_attachment.api_psc,
│   on modules/infrastructure/networking.tf line 130, in resource "google_compute_service_attachment" "api_psc":
│  130: resource "google_compute_service_attachment" "api_psc""

Fix: 
in resource networking.tf > "google_compute_service_attachment" "api_psc" 
Change connection_preference to manual: 

connection_preference = "ACCEPT_MANUAL"

Then: 

terraform -chdir=platform/GCP/terraform validate

Expected output:  

"Success! The configuration is valid"

Run: 

```bash
gcloud compute backend-services update apigee-northbound-backend \
  --project=rocketcodeapigee \
  --region=us-south1 \
  --security-policy=""
```

re-try terraform apply infra module: 
terraform apply -var-file="./environments/DEV/dev.tfvars" -target=module.infrastructure

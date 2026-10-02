# Terraform apply failure investigation: wrong active GCP project context and Cloud Build source/config errors

## Symptom

The root command failed while Terraform attempted to create the infrastructure module:

```bash
cd platform/GCP/terraform
terraform apply -var-file="./environments/DEV/dev.tfvars" -target=module.infrastructure
```

The relevant errors were:

```text
Error: Error creating Trigger: googleapi: Error 400: Request contains an invalid argument.
```

and

```text
Error: local-exec provisioner error
Unable to read file [APPS/hello-backend/cloudbuild.yaml]: [Errno 2] No such file or directory
```

The local Cloud Build step also failed with an image-tag parse problem and the build context trying to resolve a Dockerfile under a nested path.

## Root cause 1: wrong active GCP project context

The initial backend/state error was caused by the wrong active project context. Terraform was using the wrong project (`dev-mockbank`) instead of the intended project (`rocketcodeapigee`).

Once the project was corrected with:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/home/pochitawork/RocketCodeKey/rocketcodeapigee-8e40c433aebd.json"
gcloud config set project rocketcodeapigee
```

Terraform could initialize the remote backend and run the plan normally.

## Root cause 2: invalid repo-backed Cloud Build trigger logic

The project does not have a GitHub repository or Cloud Source Repository connected to Cloud Build. Because of that, a `google_cloudbuild_trigger` resource would fail with an invalid request during creation. This is a Cloud Build configuration error, not a Terraform syntax error.

The repository was therefore treated as a local/manual build pattern instead of a repo-triggered build.

## Root cause 3: mismatched source root and Cloud Build working directory

The local build command was effectively doing this:

```bash
gcloud builds submit --config=APPS/hello-backend/cloudbuild.yaml --substitutions=... APPS/hello-backend
```

but the YAML file was also setting:

```yaml
dir: "APPS/hello-backend"
```

This created a nested path problem. The Cloud Build workspace was already rooted at the app directory, so Cloud Build was looking for:

```text
/workspace/APPS/hello-backend/Dockerfile
```

instead of:

```text
/workspace/Dockerfile
```

The local build command and the YAML build context must match. The build context must be the app directory itself (`.` or no `dir`), not a nested `APPS/hello-backend` path when the source root is already the app directory.

## Root cause 4: invalid image tag substitution during local submit

The build failed with:

```text
invalid image name "us-south1-docker.pkg.dev/.../rocketcode-demo-backend:": could not parse reference
```

This happened because the tag substitution was not being resolved correctly for the local build. The build uses a short SHA value, and the tag must always include a non-empty value after the final colon. The more reliable pattern is to set a concrete tag value (`latest` or a valid generated SHA string) and ensure the substitution key is defined consistently.

## Correct model used for the final implementation

The working pattern is:

- keep the build as a local `gcloud builds submit` step
- submit the actual app directory as the source root
- keep the build YAML at the app root with no `dir` override
- use valid image names and non-empty tags
- do not create a repo-backed trigger unless Cloud Build is explicitly linked to a repo

## Current status after correction

This command now succeeds:

```bash
cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/platform/GCP/terraform
terraform init -reconfigure
terraform plan -var-file="./environments/DEV/dev.tfvars" -target=module.infrastructure
```

The current plan is not a failure; it shows the expected infrastructure drift for the repository:

- create `module.infrastructure.google_cloudbuild_trigger.hello_backend_trigger`
- replace `module.infrastructure.google_compute_region_security_policy.api_armor_policy`
- replace tainted `module.infrastructure.terraform_data.build_hello_backend`

The configuration is valid and the underlying cause of the original failure was the incorrect active project context, not a broken billing setup.

## Additional fix made

The root module was missing declarations for some variables already present in `environments/DEV/dev.tfvars`, which caused undeclared-variable warnings. Those were added to `platform/GCP/terraform/variables.tf` so the Terraform plan cleanly resolves the variables in the DEV environment file.

## Operational guidance

Before running Terraform:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/home/pochitawork/RocketCodeKey/rocketcodeapigee-8e40c433aebd.json"
gcloud config set project rocketcodeapigee
```

Then validate and plan:

```bash
cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/platform/GCP/terraform
terraform init -reconfigure
terraform validate
terraform plan -var-file="./environments/DEV/dev.tfvars" -target=module.infrastructure
```

Only apply after reviewing the plan and confirming the remaining actions are intentional.

## Terraform apply error: Invalid index on observability alert outputs

### Symptom

Running the observability module failed with:

```bash
terraform apply -var-file="./environments/DEV/dev.tfvars" -target=module.observability
```

Terraform returned:

```text
Error: Invalid index
│ 
│   on modules/observability/outputs.tf line 8, in output "alert_policy_high_latency_id":
│    8:   value       = var.enable_alerting ? google_monitoring_alert_policy.high_backend_latency[0].id : null
│     ├────────────────
│     │ google_monitoring_alert_policy.high_backend_latency is empty tuple
│ 
│ The given key does not identify an element in this collection value: the collection has no elements.
```

### Root cause

The alert resources in `platform/GCP/terraform/modules/observability/alerts.tf` are created with `count`:

```hcl
count = var.enable_alerting && var.create_alerts_when_metrics_ready ? 1 : 0
```

When `create_alerts_when_metrics_ready` is `false`, the resource list is empty. The module outputs still tried to read `[0]`, which causes Terraform to fail with `Invalid index`.

### Fix

Guard each access with a length check before indexing:

```hcl
value = var.enable_alerting && length(google_monitoring_alert_policy.high_backend_latency) > 0 ? google_monitoring_alert_policy.high_backend_latency[0].id : null
```

The same pattern should be used for each alert output and the notification channel output.

### Corrected files

- `platform/GCP/terraform/modules/observability/outputs.tf`

### Validation

The fix was validated with:

```bash
cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/platform/GCP/terraform
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

### Operational guidance

If alert creation is intentionally gated until metrics are available, keep the `create_alerts_when_metrics_ready` flag set to `false` and ensure outputs never index into empty resource tuples. This prevents apply-time failures while still allowing observability resources to be created later once the metrics are confirmed ready.

---

## Related references

- `platform/GCP/terraform/modules/infrastructure/cloudbuild.tf`
- `APPS/hello-backend/cloudbuild.yaml`
- `platform/GCP/terraform/modules/infrastructure/cloudrun.tf`
- `changelog.md`

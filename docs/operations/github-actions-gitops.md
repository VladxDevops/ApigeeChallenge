# GitHub Actions GitOps Pipeline

## Purpose

This document defines the first reproducible deployment pipeline. GitHub Actions is the orchestrator. Terraform owns GCP infrastructure. Cloud Build builds container images. Ansible owns guarded Apigee proxy deployment and verification.

The pipeline is initially implemented for DEV and is reusable for later environments through GitHub environments and environment-specific Terraform/backend variables.

## Source repository

- Repository: `Arixxtxdevops/ApigeeChallenge`
- Initial deployment branch: `Build-DEV`
- Pull request validation: all pull requests and pushes to infrastructure automation files
- Deployment target: DEV only until later environments are declared

## Deployment flow

```text
Push to Build-DEV
  -> PR/security checks
  -> Authenticate through WIF
  -> Terraform init
  -> Terraform plan for DEV
  -> GitHub DEV environment approval
  -> Terraform apply
  -> Cloud Build image build and immutable digest
  -> Terraform Cloud Run image update
  -> Ansible proxy deployment and verification
  -> Deployment summary/artifacts
```

## Identity model

The pipeline must not use a GCP service-account JSON key.

GitHub Actions authenticates using GCP Workload Identity Federation:

```text
GitHub OIDC token
  -> WIF provider
  -> attribute/repository/branch conditions
  -> dev-terraform-deployer-sa
  -> approved GCP project APIs
```

Bindings must restrict the WIF principal to:

- Repository: `Arixxtxdevops/ApigeeChallenge`
- Initial branch: `refs/heads/Build-DEV`
- Service account: `dev-terraform-deployer-sa@apigeechallenge.iam.gserviceaccount.com`

The pool/provider resources are bootstrap infrastructure. They may require an initial local or break-glass bootstrap run before GitHub Actions can authenticate.

## Required GitHub configuration

Configure repository variables:

| Variable | Example/meaning |
|---|---|
| `DEV_GCP_PROJECT_ID` | DEV GCP project ID |
| `DEV_GCP_REGION` | DEV region |
| `DEV_GCP_WORKLOAD_IDENTITY_PROVIDER` | Full `projects/.../locations/global/workloadIdentityPools/.../providers/...` resource name |
| `DEV_TERRAFORM_DEPLOYER_SA` | `dev-terraform-deployer-sa@<project>.iam.gserviceaccount.com` |
| `DEV_TERRAFORM_STATE_BUCKET` | Globally unique GCS state bucket |

Create a GitHub environment named `DEV` with:

- Required reviewers.
- No environment-wide secrets unless required for an external system.
- Deployment branch restriction for `Build-DEV`.

## GCP APIs

The bootstrap project must enable or already have:

- `sts.googleapis.com`
- `iamcredentials.googleapis.com`
- `iam.googleapis.com`
- `cloudresourcemanager.googleapis.com`
- `cloudbuild.googleapis.com`
- `artifactregistry.googleapis.com`
- `run.googleapis.com`

The root module continues to declare environment-required APIs.

## Terraform state

Each environment must use a separate state namespace:

- DEV: `terraform/state/dev`
- Future: `terraform/state/test`, `terraform/state/uat`, or `terraform/state/prod`

Preferred isolation is separate GCS buckets and projects. A shared bucket fallback is permitted only with a separate prefix and independently restricted service accounts.

The state bucket must remain private, versioned, and protected from public access.

## Terraform responsibilities

Terraform owns:

- VPC, subnets, routes, firewalls, PSC, load balancing, Cloud Armor.
- IAM and service accounts.
- Artifact Registry.
- Cloud Run infrastructure and revision configuration.
- Apigee infrastructure and endpoint attachments.
- Monitoring and secrets metadata.

Environment changes use:

```bash
terraform -chdir=platform/GCP/terraform fmt -recursive
terraform -chdir=platform/GCP/terraform init
terraform -chdir=platform/GCP/terraform validate
terraform -chdir=platform/GCP/terraform plan \
  -var-file=environments/DEV/dev.tfvars \
  -out=dev.tfplan
```

No apply is allowed without a reviewed plan and DEV environment approval.

## Container build responsibilities

Cloud Build builds the existing `APPS/AppsPlatform/hello-backend` source.

Requirements:

- Build only the reviewed Git commit.
- Push an immutable SHA/tagged image.
- Push `latest` only for backward compatibility; deployments must not use `latest`.
- Update Terraform or Cloud Run with the digest, not a mutable tag.
- Use the project-default Cloud Build service account or a dedicated build service account with only the required push and logging permissions.

A preconfigured GitHub-connected Cloud Build trigger is optional. GitHub Actions may submit builds explicitly for initial DEV automation. Trigger registration should be documented separately if later adopted.

## Ansible responsibilities

Ansible executes only after Terraform apply and container deployment.

It owns:

- Proxy bundle validation.
- Zip generation.
- Apigee proxy import.
- Guarded proxy revision deployment.
- READY-state verification.
- Northbound smoke verification.

Ansible must not create Terraform-owned infrastructure.

The workflow must set `APIGEE_DEPLOY_ENV=dev` and must inherit Terraform outputs for project ID, runtime service account, endpoint host, and northbound IP.

## Approval and rollback

DEV applies require the GitHub `DEV` environment approval until the project is promoted to a mature test environment.

Rollback controls:

- Cloud Run: route to a known-good immutable revision/digest.
- Apigee: deploy a known-good proxy revision.
- Terraform: review and apply the prior infrastructure plan/change, never manually edit shared resources.
- WIF: remove repository/branch bindings if compromise is suspected.

## Security gates

Pull requests and deployment jobs must reject:

- Service-account key files.
- Hard-coded live project IDs or service-account emails in logs.
- Secret values in tfvars.
- Terraform changes outside the selected project/backend.
- Ansible deployment when `APIGEE_DEPLOY_ENV` does not exactly match the intended environment.
- Container deployments that reference `latest`.

The workflow must summarize plan/apply/build outcomes and upload only non-sensitive plan/log artifacts.

## Implementation checklist

- [ ] Create WIF pool and provider.
- [ ] Bind the DEV Terraform deployer identity to the trusted GitHub repository/branch.
- [ ] Configure GitHub DEV environment and variables.
- [ ] Add PR validation workflow.
- [ ] Add DEV deployment workflow.
- [ ] Separate DEV Terraform state prefix.
- [ ] Add immutable Cloud Build image digest.
- [ ] Run Ansible syntax and proxy validation.
- [ ] Run live DEV smoke tests.
- [ ] Document live WIF and Cloud Build evidence.

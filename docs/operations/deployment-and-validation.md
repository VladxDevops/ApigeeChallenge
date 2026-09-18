# Deployment and Validation

This document defines the planned deployment workflow and the evidence to collect for the technical defense.

## Preconditions

- Google Cloud project exists.
- Billing is enabled.
- Terraform deployer identity exists.
- Remote state bucket is bootstrapped or can be created by an approved bootstrap run.
- Apigee entitlement and organization type are confirmed.
- Real CIDR inventory is reviewed for overlap.
- `us-south1` quotas are available.

## Terraform Workflow

From `platform/GCP/terraform`:

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -var-file=environments/DEV/dev.tfvars
```

Do not run `terraform apply` against an unknown or shared environment without explicit approval.

## Deployment Sequence

1. Bootstrap remote state.
2. Enable required Google APIs.
3. Grant deployment IAM to the Terraform service account.
4. Create the API spoke VPC and required subnets.
5. Create Cloud Armor policy and regional external Application Load Balancer.
6. Provision Apigee with non-VPC-peering networking.
7. Connect northbound PSC from the LB path to Apigee.
8. Deploy the Cloud Run backend with restricted ingress.
9. Publish private backend access through a PSC service attachment.
10. Create the Apigee endpoint attachment for southbound PSC.
11. Configure the Apigee API proxy target.
12. Validate Cloud Run and on-premises request paths.

## Validation Evidence

| Area | Evidence |
|---|---|
| Terraform formatting | `terraform fmt -recursive -check` exits 0. |
| Terraform syntax | `terraform validate` exits 0. |
| Plan review | Plan contains expected VPC, subnet, IAM, LB, PSC, Apigee, and backend resources only. |
| No direct backend exposure | Direct Cloud Run URL returns blocked/forbidden; only LB/Apigee path works. |
| Northbound path | Request to public API domain reaches Apigee proxy. |
| Southbound Cloud Run path | Apigee proxy receives successful response from Cloud Run target through PSC. |
| Southbound on-prem path | Test endpoint confirms reachability through Hub/VPN. |
| WAF | Cloud Armor logs show allowed and denied sample requests. |
| Observability | Logs/traces correlate request IDs across LB, Apigee, backend, and VPN where available. |

## Operational Checks

- Confirm no service-account keys are committed.
- Confirm `docs/internal/` is ignored by Git.
- Confirm Terraform state files are ignored and not part of the submission.
- Confirm Apigee runtime is drawn outside the customer VPC in the final diagram.
- Confirm the diagram shows trust boundaries and traffic direction.

## Rollback Strategy

Before apply, review resource dependencies and identify resources with customer traffic impact:

- DNS records and certificates.
- Load balancer forwarding rules.
- Apigee proxy deployments.
- PSC service attachments and endpoint attachments.
- Cloud Run revisions.

For Cloud Run, prefer revision rollback. For Apigee proxies, deploy a known-good revision. For networking changes, use Terraform plan review and avoid replacing shared resources unless explicitly approved.

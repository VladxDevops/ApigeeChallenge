# CI/CD Architecture

## Trust boundaries

```text
GitHub repository/Build-DEV
  | short-lived OIDC token
WIF pool/provider
  | repository + branch conditions
DEV Terraform deployer service account
  | least-privilege GCP APIs
DEV GCP project
  | Terraform + Cloud Build + Apigee management
Infrastructure / container / proxy revisions
```


## Responsibilities

| System | Responsibility | Must not own |
|---|---|---|
| GitHub Actions | Orchestration, approvals, validation, audit summary | Live GCP credentials or persistent secrets |
| WIF | Translate a trusted GitHub OIDC assertion into GCP identity | Service-account key issuance |
| Terraform | GCP infrastructure and state | Proxy ZIP import or container source builds |
| Cloud Build | Container build and Artifact Registry push | Infrastructure state or proxy deployment |
| Ansible | Proxy import/deploy/verify | VPC, IAM, Cloud Run, or load-balancer changes |


## Initial DEV topology

DEV remains in the existing GCP project until project separation is implemented. The pipeline identity is (variable:) terraform_deployer_service_account.

Future environments should use:

- A separate GCP project.
- A separate WIF provider or a dedicated attribute condition and deployment service account.
- A separate Terraform state bucket/prefix.
- A separate GitHub environment approval policy.
- Separate tfvars and inventory values.


## Required special subnets and return traffic

The pipeline does not alter the architecture's private traffic contract. Terraform still owns:

- API private subnet.
- Proxy-only subnet for the regional external load balancer.
- PSC NAT subnet for producer side private connectivity.
- Cloud Run VPC connector subnet.

Deployment automation must verify that these resources remain private and that no direct backend exposure is introduced.


## Artifact promotion

The preferred promotion unit is an immutable container digest plus a reviewed Terraform plan and exact proxy revision.

Later environments must not rebuild an image from mutable source unless source and commit provenance are revalidated. The pipeline should promote a digest that was built from a reviewed commit.

## Failure behavior

- Terraform plan failure: stop before approval.
- Terraform apply failure: keep state and return failure details; do not proceed to image/proxy deployment.
- Cloud Build failure: stop and leave infrastructure state unchanged.
- Apigee deployment failure: leave Terraform state successful but mark the release failed; preserve the prior proxy revision.
- Verification failure: do not mark the workflow successful and retain logs for rollback.

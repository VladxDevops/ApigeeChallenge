# IAM & Identity Model — Apigee Challenge

## 1. Overview

The IAM model enforces least privilege across deployment pipelines, service-to-service communications, runtime workloads, and administrative access.

## 2. Identity Inventory

| Identity Name | Type | Module Owner | Granted Roles | Purpose |
|---|---|---|---|---|
| `dev-terraform-deployer-service` | Service Account | `modules/iam` | `roles/compute.networkAdmin`, `roles/run.admin`, `roles/apigee.admin`, `roles/iam.serviceAccountUser` | IaC deployment pipeline |
| `cloud-run-backend-sa` | Service Account | `modules/security` | `roles/secretmanager.secretAccessor`, `roles/logging.logWriter`, `roles/monitoring.metricWriter` | Cloud Run runtime identity |
| `apigee-dev-admin-sa` | Service Account | `modules/apigee` | `roles/apigee.admin` | Dedicated Apigee org administration |

## 3. Principles & Controls

1. **Separation of Duties**:
   - Deployment identities are completely separate from workload execution identities.
   - Cloud Run uses `cloud-run-backend-sa`, never the default Compute Engine service account.

2. **Least Privilege**:
   - No primitive roles (`roles/owner`, `roles/editor`) are used.
   - Cloud Run runtime SA is scoped strictly to reading secrets and emitting observability metrics/logs.

3. **Service-to-Service Authorization**:
   - Cloud Run ingress is restricted to `INTERNAL_ONLY`.
   - Invocation via ILB/PSC requires explicit IAM invoker permissions.

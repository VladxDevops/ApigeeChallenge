+++
title = "Apigee Terraform Module — Non-VPC-Peering Runtime"
domain = "terraform"
tier = 3
topics = ["terraform", "apigee", "psc", "non-vpc-peering", "endpoint-attachment"]
parent = "platform/GCP/terraform/README.md"
children = []
related = [
    "docs/architecture/architecture.md",
    "docs/networking/network-architecture.md",
    "docs/architecture/traffic-flows.md",
    "docs/decisions/architecture-decisions.md",
    "platform/GCP/terraform/modules/infrastructure/Agents.md"
]
updated_by = "Grok"
version = "1.0"
+++

> **Parent**: [`platform/GCP/terraform/README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/platform/GCP/terraform/README.md)
> **Architecture**: [`architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/architecture.md)
> **Network**: [`network-architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/network-architecture.md)
> **Flows**: [`traffic-flows.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/traffic-flows.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Scope and status of platform/GCP/terraform/modules/apigee. Names what this module is meant to own and what neighboring modules already own.
- Questions Answered: Does this module provision Apigee today? Which resources belong here versus infrastructure, security, and APPS/APIgee? What must the northbound service attachment and southbound endpoint attachment connect to?
- When to Retrieve: Before adding Apigee organization, instance, environment, or endpoint-attachment Terraform.
- When NOT to Retrieve: Editing the API spoke VPC, the regional external load balancer, Cloud Run, firewalls, or proxy bundle XML.
-->


# Apigee Terraform module

This directory is the home for the provider-managed Apigee runtime in the Rocket Code exercise: non-VPC-peering networking in `us-south1`, with Private Service Connect on both sides of the runtime.

Run Terraform from `platform/GCP/terraform/`. This folder is a module. It has no backend.


## Current status

Nothing in this directory is applied.

| File | State |
|---|---|
| `main.tf` | Empty. No `google_apigee_*` resources. |
| `Agents.md` | Edit contract for this directory. |
| `README.md` | This document. |

`platform/GCP/terraform/infrastructure.tf` does not instantiate `module "apigee"`. A `terraform plan` from the root therefore creates no Apigee organization, instance, environment, or endpoint attachment.

The customer project still expects an Apigee-published northbound service attachment. `modules/infrastructure` reads that URI from `var.apigee_northbound_service_attachment` and builds the regional external Application Load Balancer and PSC network endpoint group only when the URI is present and is not a placeholder. Until this module (or an operator) supplies that URI, the northbound chain stays off.


## What this module is for

Decisions 1, 2, and 4 select Apigee, non-VPC peering, and southbound PSC endpoint attachments. This module is the control-plane place for that runtime. The runtime stays outside the customer VPC. This module does not assign a customer CIDR to Apigee and does not create a peered network.

Target data paths, once the runtime exists:

```text
Internet
  -> regional external Application Load Balancer   (modules/infrastructure)
  -> Cloud Armor
  -> PSC network endpoint group
  -> Apigee northbound service attachment          (published by this module's instance)
  -> Apigee runtime
  -> Apigee endpoint attachment                    (this module)
  -> customer PSC service attachment               (modules/infrastructure)
  -> internal Application Load Balancer
  -> Cloud Run
```

Northbound: this module's job ends at the service attachment Apigee publishes. The load balancer that consumes it lives in `modules/infrastructure`.

Southbound: `modules/infrastructure` publishes `google_compute_service_attachment.api_psc` and accepts only `var.apigee_consumer_project_id`. This module creates the Apigee endpoint attachment that connects to that service attachment. Proxy TargetEndpoint configuration that uses the attachment host belongs with the proxy bundles under `APPS/APIgee/proxies/`.



## Ownership

| Concern | Owner |
|---|---|
| Apigee organization, instance, environment group, environment | This module, when implemented |
| Northbound service attachment URI exported for the load balancer | This module's output, consumed by root `apigee_northbound_service_attachment` |
| Southbound endpoint attachment | This module |
| API spoke VPC, subnets, producer service attachment, regional external load balancer, Cloud Run | `modules/infrastructure` |
| Apigee admin service account (`apigee_admin_service_account_name_dev`) and `roles/apigee.admin` | This module. Retire `apigee-admin-sa` in `modules/security`. |
| Dashboards and the `apigee_target_errors` log metric | `modules/observability` |
| API proxy bundles | `APPS/APIgee/proxies/` |
| `apigee.googleapis.com` and other project APIs | `modules/enable-gcp-services` (Apigee API is not enabled there today) |



## Invariants for a future implementation

- Do not set an Apigee authorized network or an instance peering CIDR. That is the VPC-peering model, which this exercise rejected.
- Do not create customer VPC networks, subnets, load balancers, or firewall rules in this module.
- Do not point the northbound PSC network endpoint group at `google_compute_service_attachment.api_psc`. That attachment is the southbound producer. Infrastructure already rejects a URI that contains `api-psc-service-attachment`.
- The endpoint attachment's target is the infrastructure service attachment URI. Connection preference on that attachment stays `ACCEPT_MANUAL`.
- Region stays `us-south1`, taken from a variable. Do not hardcode a second region.
- Organization billing type (evaluation, pay-as-you-go, or subscription) is still an open assumption in `docs/assumptions/assumptions-risks-tradeoffs.md`. Do not pick one silently in examples.
- The organization `project_id` is `var.compute_project_id`.
- `analytics_region` is `var.compute_region`, not a hardcoded `us-south1`.
- Admin calls use `var.apigee_admin_service_account_name_dev` in this module. Do not also keep `apigee-admin-sa` in `modules/security`. Do not write a JSON key.
- Exact Google provider arguments for a non-VPC-peering organization and for reading the instance's northbound service attachment are `UNVERIFIED` in this repository. Confirm them against current Apigee and `hashicorp/google` documentation before adding resources. `docs/networking/network-architecture.md` already notes that steps from organization provisioning through the endpoint attachment may need sequencing beyond a single Terraform apply.



## Intended interface

These names are the contract to wire at the root. They are not declared in this directory yet.

| Input | Source | Purpose |
|---|---|---|
| `compute_project_id` | Root variable | Project that hosts the Apigee organization |
| `compute_region` | Root variable, `us-south1` | Instance location, endpoint attachment location, and `analytics_region` |
| `southbound_service_attachment` | `module.infrastructure` service attachment self link | Target of the endpoint attachment |
| `apigee_admin_service_account_name_dev` | Root variable | `account_id` of the admin service account created in this module |

| Output | Consumer | Purpose |
|---|---|---|
| `organization_id` | Callers that need the organization id | The organization is created in `var.compute_project_id`. `roles/apigee.admin` is bound in this module on `apigee_admin_service_account_name_dev`. |
| `northbound_service_attachment` | Root `apigee_northbound_service_attachment` | Opens the infrastructure northbound load-balancer chain |
| `endpoint_attachment_host` | Proxy target configuration | Host or DNS name the TargetEndpoint uses |

There is no usage example that applies. Adding `module "apigee"` to `infrastructure.tf` is a separate change, after the resources exist and the `UNVERIFIED` provider arguments are checked.



## Preconditions before that work

- `apigee.googleapis.com` enabled on the project.
- `roles/apigee.admin` bound in this module on `apigee_admin_service_account_name_dev`. The security-module account `apigee-admin-sa` is not the admin identity.
- The infrastructure service attachment already applied, because the endpoint attachment depends on it.
- No `terraform apply` without an authorization that names the environment. Provisioning an Apigee organization is slow and hard to reverse.


## Checks

From `platform/GCP/terraform/`, after resources exist:

```text
terraform fmt -recursive
terraform validate
```

Review the plan for organization, instance, and endpoint-attachment creates. Confirm it does not add an authorized network, a peering CIDR, or a replacement of `api-spoke-vpc` and its subnets.

Evidence to collect is listed in `docs/operations/deployment-and-validation.md`: the runtime drawn outside the customer VPC, a northbound request that reaches the proxy, and a southbound response from Cloud Run through the endpoint attachment.

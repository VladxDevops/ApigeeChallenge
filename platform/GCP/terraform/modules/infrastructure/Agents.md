+++
title = "Infrastructure Module — Agent Rules"
domain = "terraform"
tier = 3
topics = ["terraform", "infrastructure", "vpc", "psc", "cloud-run", "cloud-armor", "load-balancer"]
parent = "AGENTS.md"
children = []
related = [
    "docs/networking/network-architecture.md",
    "docs/networking/addressing-plan.md",
    "docs/architecture/traffic-flows.md",
    "docs/architecture/CloudRun/CloudRun-requirements.md",
    "docs/security/security-model.md",
    "docs/TROUBLESHOOTING/postmortem.md"
]
updated_by = "Grok"
version = "1.0"
+++

> **Parent**: [`AGENTS.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AGENTS.md)
> **Design**: [`network-architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/network-architecture.md)
> **CIDRs**: [`addressing-plan.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/addressing-plan.md)
> **Flows**: [`traffic-flows.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/traffic-flows.md)
> **Armor incident**: [`postmortem.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/TROUBLESHOOTING/postmortem.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Directory rules for editing platform/GCP/terraform/modules/infrastructure. Names the resources this module owns, the invariants that must survive a change, and the checks to run from the Terraform root.
- Questions Answered: Which file owns the VPC, the ILB, the northbound ALB, Cloud Run, and Artifact Registry? What must not be renamed, duplicated, or moved into the security module? How is northbound creation gated?
- When to Retrieve: Any edit under modules/infrastructure.
- When NOT to Retrieve: Firewall rules, Secret Manager, service-account creation, dashboards, or Apigee org provisioning. Those live in other modules.
-->


# Infrastructure module

Rules for work under `platform/GCP/terraform/modules/infrastructure/`. The shared contract is repo-root [`AGENTS.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AGENTS.md). Product behavior comes from official Google Cloud and Terraform docs. This file says how to change this module without breaking the data path.

Run Terraform from `platform/GCP/terraform/`, never from this directory. This folder is a module (`source = "./modules/infrastructure"` in `infrastructure.tf`). It has no backend and no root module block.


## What this module owns

| File | Owns |
|---|---|
| `networking.tf` | API spoke VPC, three subnets, southbound PSC producer path, northbound regional external ALB, regional Cloud Armor policy, dev TLS fallback |
| `cloudrun.tf` | Private Cloud Run service |
| `artifact-registry.tf` | Docker Artifact Registry repository |
| `variables.tf` | Module inputs |
| `versions.tf` | `hashicorp/google` `>= 5.26.0`, `hashicorp/tls` `>= 4.0.0` |
| `main.tf` | Network outputs only: `api_spoke_network_id`, `api_private_subnet_id`, `proxy_only_subnet_id`, `psc_nat_subnet_id` |

`README.md` in this directory is empty. It is not a spec. Read the `.tf` files and the design docs linked above.

Leave these in their own modules:

- Firewalls, IAM service accounts, Secret Manager, and the global `google_compute_security_policy.api_spoke_waf`: `modules/security/`.
- Dashboards, log sinks, alerts: `modules/observability/`.
- Apigee organization, instance, and endpoint attachment: not this module. Northbound only *consumes* the service-attachment URI Apigee publishes.

The security module reads `module.infrastructure.api_spoke_network_id`. Renaming or removing that output requires a matching edit in `platform/GCP/terraform/infrastructure.tf`.


## Data paths encoded here

Southbound (always created):

```text
Apigee consumer
  -> google_compute_service_attachment.api_psc
  -> google_compute_forwarding_rule.api_ilb          (INTERNAL_MANAGED, port 80)
  -> google_compute_region_target_http_proxy.api_proxy
  -> google_compute_region_backend_service.api_backend
  -> google_compute_region_network_endpoint_group.cloud_run_neg   (SERVERLESS)
  -> google_cloud_run_v2_service.api_backend
```

Northbound (created only when `local.has_valid_apigee_attachment` is true):

```text
google_compute_forwarding_rule.apigee_northbound     (EXTERNAL_MANAGED, 443, STANDARD tier)
  -> google_compute_region_target_https_proxy.apigee_northbound
  -> google_compute_region_backend_service.apigee_northbound
       security_policy = google_compute_region_security_policy.api_armor_policy
  -> google_compute_region_network_endpoint_group.apigee_psc_neg  (PRIVATE_SERVICE_CONNECT)
  -> var.apigee_northbound_service_attachment
```

`google_compute_region_security_policy.api_armor_policy` is created even when the northbound chain is gated off. Keep that split unless the user asks to change it.


## Invariants

VPC and subnets:

- `google_compute_network.api_spoke` stays custom mode (`auto_create_subnetworks = false`).
- `api_private` is a regular subnet with `private_ip_google_access`. It holds the internal forwarding-rule address. It is not a proxy-only subnet and not a PSC NAT subnet.
- `regional_proxy_only` keeps `purpose = "REGIONAL_MANAGED_PROXY"` and `role = "ACTIVE"`. GCP rejects a proxy-only prefix longer than `/26`. Both forwarding rules depend on it. Neither forwarding rule sets `subnetwork` to this subnet. Envoy uses it automatically.
- `psc_nat` keeps `purpose = "PRIVATE_SERVICE_CONNECT"`. GCP's minimum is `/29`. It appears only as `nat_subnets` on `google_compute_service_attachment.api_psc`. Do not place VMs, the ILB address, or a connector here.
- `var.api_vpc_cidr` documents the supernet. No resource takes its address range. Do not create a subnet from the `/16`.
- CIDR values stay in variables. Do not hardcode them in `networking.tf`.

Addressing: [`addressing-plan.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/addressing-plan.md) is the source. `environments/DEV/dev.tfvars` still has `10.80.1.0/28`, `10.80.3.0/29`, and `10.80.2.0/26`. Update the tfvars to `10.80.0.0/28`, `10.80.0.16/29`, and `10.80.0.64/26`, and record the change in `changelog.md`. Those subnets are already applied, so the next apply replaces them. Do not edit the addressing plan to match the old tfvars.

Southbound PSC and Cloud Run:

- The producer load balancer stays `INTERNAL_MANAGED` with a serverless NEG. A passthrough internal network load balancer cannot front Cloud Run. Do not add a health check on `google_compute_region_backend_service.api_backend`; serverless NEG backends do not use one.
- The NEG's `cloud_run.service` stays `var.cloud_run_service_name`, the same name as `google_cloud_run_v2_service.api_backend`.
- The service attachment stays `connection_preference = "ACCEPT_MANUAL"` and accepts only `var.apigee_consumer_project_id`. Do not switch it to `ACCEPT_AUTOMATIC` and do not hardcode a project id or project number in the module.
- Cloud Run ingress stays `INGRESS_TRAFFIC_INTERNAL_ONLY`. Do not set `INGRESS_TRAFFIC_ALL`.
- `google_cloud_run_v2_service_iam_member.cloud_run_invoker` grants `roles/run.invoker` to `allUsers` so the internal load balancer can call the service. Ingress restriction is what keeps that off the internet. Removing `allUsers` without an invoker the ILB actually uses breaks southbound. Widening ingress to compensate is not allowed.
- A dedicated runtime service account belongs to the security module and arrives through `var.cloud_run_service_account_email`. Empty means the Cloud Run default. Do not create a second service account in this module. Wiring a new value also means passing it from `infrastructure.tf`.

Northbound:

- New resources in this chain use `count = local.has_valid_apigee_attachment ? 1 : 0` and index `[0]`. The gate is false when the URI is empty, contains `PLACEHOLDER`, or contains `api-psc-service-attachment` (that string is the southbound attachment's name). Do not point the PSC NEG at this module's own service attachment.
- The forwarding rule and its address stay `network_tier = "STANDARD"`. A regional external Application Load Balancer does not use `PREMIUM`.
- Protocol on the northbound backend stays `HTTPS`. The listener stays `443`.
- Keep `lifecycle.create_before_destroy` on `apigee_psc_neg` when replacing the attachment URI.
- `tls_private_key` and `tls_certificate` are sensitive inputs. Do not add them to outputs, logs, or committed examples. A self-signed cert (`tls_private_key.default_self_signed`, CN `api.example.com`) exists only for dev when the northbound gate is open and the inputs are empty or placeholders. Say so if a change depends on it. Do not treat that cert as the submission TLS design.

Cloud Armor in this module:

- The policy attached to the northbound backend is the regional `google_compute_region_security_policy.api_armor_policy` (`name = "api-armor-policy"`). Remove the global `google_compute_security_policy.api_spoke_waf` in `modules/security`. A regional `EXTERNAL_MANAGED` backend cannot use that global policy.
- Put rules in the `rules` blocks of that resource. Do not add `google_compute_region_security_policy_rule`. Standalone rule resources made apply fail on refresh; see [`postmortem.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/TROUBLESHOOTING/postmortem.md).
- The inline deny of `9.9.9.9/32` is an example. Replacing it is a security-model change, not a drive-by cleanup.

Names already applied (`api-spoke-vpc`, `api-private-us-south1`, `api-proxy-only-us-south1`, `api-psc-nat-us-south1`, and the load-balancer names in `networking.tf`) are live identifiers. Renaming them replaces infrastructure. Do not rename for style. New resources take `var.compute_region` and `var.compute_project_id`. The subnet names contain `us-south1`; changing region without a planned rename leaves those names behind.

`google_artifact_registry_repository.helo_apigee_repo` ignores label changes. Leave that lifecycle rule in place unless the user wants Terraform to adopt labels.


## How to edit

- Add a variable in `variables.tf` with a description. If it has no default, pass it from `platform/GCP/terraform/infrastructure.tf` and declare it on the root module. Root and module variables drift today (`cloud_run_*` defaults exist only on the module). Do not add a third copy.
- Keep environment values in tfvars. This module does not read tfvars itself.
- Do not add firewall resources here. If a path needs a firewall change, edit `modules/security/` and keep using the network id output.
- Do not provision the Apigee runtime, a customer `/22`, or a peered Apigee network from this module.
- Do not add a Serverless VPC Access connector unless Cloud Run must open its own connections into the VPC. The current path is ILB to serverless NEG, which does not need one. The addressing plan reserves `10.80.0.32/28` for that connector; creating it is an addressing change.
- A new output that another module needs is declared next to the existing outputs and wired at the root. Cloud Run and Artifact Registry outputs stay in their own files.


## Checks

From `platform/GCP/terraform/`:

```text
terraform fmt -recursive
terraform validate
```

Run `terraform plan` when credentials and the existing backend are available. Read the plan for subnet, forwarding-rule, service-attachment, and Cloud Run replacements before telling the user the change is safe.

`terraform apply` and `terraform destroy` need an explicit user authorization that names the environment. Do not apply from this module directory.

After a change that alters a flow, a CIDR, or which policy is attached, update the matching doc under `docs/networking/`, `docs/architecture/traffic-flows.md`, or `docs/security/security-model.md`, plus `changelog.md`.

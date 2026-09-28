+++
title = "Hybrid Connectivity Module — Agent Rules"
domain = "terraform"
tier = 3
topics = ["terraform", "hybrid-connectivity", "vpn", "hub-vpc", "on-premises", "bgp"]
parent = "AGENTS.md"
children = []
related = [
    "docs/networking/network-architecture.md",
    "docs/networking/addressing-plan.md",
    "docs/architecture/traffic-flows.md",
    "docs/security/security-model.md",
    "platform/GCP/terraform/modules/infrastructure/Agents.md",
    "platform/GCP/terraform/modules/security/Agents.md"
]
updated_by = "Claude"
version = "1.0"
+++

> **Parent**: [`AGENTS.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AGENTS.md)
> **Design**: [`network-architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/network-architecture.md)
> **CIDRs**: [`addressing-plan.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/addressing-plan.md)
> **Flows**: [`traffic-flows.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/traffic-flows.md)
> **Sibling**: [`infrastructure/Agents.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/platform/GCP/terraform/modules/infrastructure/Agents.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Directory rules for editing platform/GCP/terraform/modules/hybrid-connectivity. Names the resources this module owns and what it must not become responsible for.
- Questions Answered: Why does this module create two VPCs instead of one? What is simulated vs real? Where does the PSK live? Why is there no API-spoke-to-hub wiring here?
- When to Retrieve: Any edit under modules/hybrid-connectivity.
- When NOT to Retrieve: API spoke VPC, Cloud Run, Apigee, Cloud Armor, or IAM for the deployer account. Those live in other modules.
-->

# Hybrid connectivity module

Rules for work under `platform/GCP/terraform/modules/hybrid-connectivity/`. The shared contract is repo-root [`AGENTS.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AGENTS.md). This file says how to change this module without breaking the simulated Hub/on-premises path or silently turning a demo into something that looks like real infrastructure.

Run Terraform from `platform/GCP/terraform/`, never from this directory. This folder is a module (`source = "./modules/hybrid-connectivity"`). It has no backend and no root module block.


## Why this module exists

`docs/networking/network-architecture.md` and `docs/networking/addressing-plan.md` both describe the Hub VPC and on-premises network as an **external dependency** — CIDRs marked `ASSUMPTION`, routes and peer details listed as "required data to confirm," never actually provisioned. The challenge has no real data center to connect to.

This module fills that gap for demo purposes: it creates a stand-in Hub VPC and a stand-in on-premises VPC in the same project, connected by a real HA VPN, so `terraform apply` produces something end-to-end testable for the oral defense. It does not represent, and must not be mistaken for, confirmed real-world Hub or on-premises infrastructure.


## What this module owns

| File | Owns |
|---|---|
| `main.tf` | Simulated Hub VPC + subnet, simulated on-premises VPC + subnet, HA VPN gateways (both sides), Cloud Routers + BGP peers (both sides), 4 VPN tunnels, generated PSK + its Secret Manager entry, on-prem ingress firewall rule |
| `variables.tf` | Module inputs, including the `simulate_hub_and_onpremises` toggle |
| `outputs.tf` | Network IDs, hub router name, tunnel names |
| `versions.tf` | `hashicorp/google` `>= 5.26.0`, `hashicorp/random` `>= 3.5.0` |

`README.md` in this directory explains what's real and what's simulated. Read it before assuming any resource here maps to production infrastructure.

Leave these in their own modules:

- The API spoke VPC, its subnets, PSC objects, and the northbound/southbound load balancers: `modules/infrastructure/`.
- Firewall rules for the API spoke VPC (`allow_backend_to_hub` and friends), Cloud Armor, and deployer/runtime IAM: `modules/security/`.
- Anything Apigee: `modules/apigee/`.
- The API-spoke-to-Hub-VPC leg (peering, Shared VPC, or Network Connectivity Center): **not built anywhere yet**. `network-architecture.md` lists this as still-unconfirmed. Do not add it here without the user asking — this module's boundary stops at the hub side of that gap.


## Invariants

Scope and simulation boundary:

- Every resource in this module is gated behind `var.simulate_hub_and_onpremises` (default `true`). Do not remove the `count` gate to "simplify" the module — the day a real Hub VPC and peer gateway are confirmed, this whole module should be switched off (`false`) rather than deleted, so the demo path stays available for reference.
- Do not point any resource here at real, non-simulated infrastructure. If the user provides a real peer IP, real PSK, or real Hub VPC self-link, that is a *different* module (a real-hub variant), not an edit to this one's simulated resources.
- Both simulated networks (`sim-hub-vpc`, `sim-onprem-vpc`) are custom-mode (`auto_create_subnetworks = false`), matching the convention in `modules/infrastructure/networking.tf`.

VPN and routing:

- HA VPN only. Do not downgrade to Classic VPN (no SLA, no BGP) — the 99.99% topology (two tunnels per side, two router interfaces per side) is intentional, not over-engineering to trim.
- BGP ASNs (`hub_router_asn`, `onprem_router_asn`) must stay distinct. Do not default them to the same value.
- The tunnel interface IPs (`169.254.0.0/30`, `169.254.1.0/30`) are GCP's standard HA VPN link-local ranges, not part of the addressing plan's RFC1918 allocations. Do not source them from `addressing-plan.md` variables.
- Destroy order (interfaces/peers → tunnels → gateways/routers → networks) is handled by Terraform's implicit dependency graph through resource references. Do not add explicit `depends_on` that could mask a broken reference, and do not `-target` a partial destroy of this module.

Secrets:

- The shared secret is generated with `random_password`, never a literal in code or tfvars — `security-model.md` explicitly prohibits committing VPN pre-shared keys.
- Storing it in Secret Manager is gated by `var.enable_secret_manager`, mirroring the root toggle of the same name. Do not hardcode `true`.
- Do not add the shared secret to any `output` block, even a "sensitive" one meant for debugging.

Firewall:

- `onprem_allow_from_hub_and_spoke` is a demo-scoped rule, explicitly narrower ports would be a security-model change. Do not widen its `source_ranges` or ports without the user asking — treat it the same way `Agents.md` (infrastructure) treats the Cloud Armor `9.9.9.9/32` example rule: a placeholder, not a drive-by cleanup target.
- Do not add firewall rules for the API spoke VPC here. Those belong in `modules/security/` against `var.api_spoke_network_id`.

Naming:

- All simulated resources are prefixed `sim-` (`sim-hub-vpc`, `sim-onprem-vpc`, `sim-hub-vpn-gw`, etc.). Keep this prefix on any new resource added to this module — it is the signal to a reader that the resource is a stand-in, not real hub/on-prem infrastructure.


## How to edit

- Add a variable in `variables.tf` with a description, following the existing pattern of defaulted CIDRs and ASNs.
- If the user asks to point this module at a *real* Hub VPC instead of a simulated one, do not repurpose `google_compute_network.hub` — that changes this module's meaning from "demo" to "production integration" silently. Ask whether they want a new module or a data-source variant, and update `network-architecture.md`'s Hub-and-On-Premises section either way.
- A new output another module needs is declared next to the existing outputs. Do not export the PSK.
- Do not add a VM, Cloud SQL instance, or other workload standing in for the "Java application" / "RDBMS" boxes in `Architecture-baseline.md` without being asked — this module's stated scope is VPN and networks only.


## Checks

From `platform/GCP/terraform/`:

```text
terraform fmt -recursive
terraform validate
```

Run `terraform plan` before telling the user a change is safe. After apply, verify BGP actually came up:

```text
gcloud compute routers get-status sim-hub-router --region=<region> --project=<project>
gcloud compute routers get-status sim-onprem-router --region=<region> --project=<project>
```

Both sessions should report `state: UP`. If they don't, check that the shared secret matches on both tunnel pairs (it should, since both reference the same `random_password` resource) and that
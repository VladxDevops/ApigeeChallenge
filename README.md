+++
title = "Public README — Rocket Code Apigee Challenge"
domain = "entry-point"
tier = 1
topics = ["apigee", "gcp", "overview", "getting-started"]
parent = "README.md"
children = [
    "docs/architecture/architecture.md",
    "docs/decisions/architecture-decisions.md",
    "docs/networking/addressing-plan.md",
    "docs/security/security-model.md",
    "docs/assumptions/assumptions-risks-tradeoffs.md"
]
related = [
    "AGENTS.md",
    "AI_MANIFEST.toml",
    "Challenge/challenge.md",
    "Architecture-baseline.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Requirements**: [`Challenge/challenge.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/Challenge/challenge.md)
> **Agent Contract**: [`AGENTS.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AGENTS.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Public executive summary and entry point for the Rocket Code Apigee Challenge repository.
- Questions Answered: What is this project? Where do I start? What are the key documents? What is the project status?
- When to Retrieve: First orientation, when routing to the correct document, or when generating a project overview.
- When NOT to Retrieve: Deep diving into specific architecture, networking CIDRs, security controls, or Terraform implementation.
-->

# Rocket Code — Cloud Engineer DevOps Technical Exercise

This repository contains the proposed GCP + Terraform solution for the API exposure and private-connectivity technical evaluation.

## Start here

1. Read `AGENTS.md`.
2. Read this `README.md`.
3. Review `docs/architecture/architecture.md` once the architecture is established.
4. Review `docs/decisions/architecture-decisions.md`.
5. Review `docs/networking/addressing-plan.md`.
6. Review `docs/security/security-model.md`.
7. Review `docs/assumptions/assumptions-risks-tradeoffs.md`.

Internal working material is intentionally kept under `/internalDocumentation/` and is Git-ignored.

## Status

Architecture: 
Selected baseline is Apigee non-VPC-peering in `us-south1`, using Private Service Connect for northbound and southbound private connectivity.  
Terraform: 
Planning scaffold exists under `platform/GCP/terraform`; implementation is intentionally incremental and starts with APIs, IAM, VPC, proxy-only subnet, and PSC NAT subnet.  
Validation: 
Documentation consistency reviewed against `Challenge/challenge.md` and current Google Cloud / Apigee documentation. Terraform formatting and validation should be run before any plan.  
Submission artifacts: 
Core public documents exist under `docs/`; generate the final diagram PNG/PDF after the Terraform resource topology is finalized.

## Selected design in one paragraph

External clients reach a regional external Application Load Balancer protected by Cloud Armor. The load balancer sends API traffic to the provider-managed Apigee runtime through northbound Private Service Connect. Apigee remains outside the customer VPC and is not assigned organization-owned CIDRs. For private targets, Apigee uses southbound Private Service Connect endpoint attachments to reach service attachments published from the customer-controlled API/backend VPC. Cloud Run is the baseline cloud application backend and is reachable only through private/load-balancing paths. Existing on-premises systems remain behind the central Hub VPC and Cloud VPN; no backend is directly exposed to the Internet.

## Key documents

- `docs/architecture/architecture.md` - architectural overview.
- `docs/architecture/traffic-flows.md` - end-to-end data-plane flows and return paths.
- `docs/networking/network-architecture.md` - network components to provision.
- `docs/networking/addressing-plan.md` - proposed non-overlapping ranges.
- `docs/decisions/architecture-decisions.md` - decision record for the oral defense.
- `docs/security/security-model.md` - authentication, authorization, TLS, secrets, and IAM.
- `docs/assumptions/assumptions-risks-tradeoffs.md` - declared assumptions and open risks.
- `docs/operations/deployment-and-validation.md` - Terraform deployment and evidence plan.

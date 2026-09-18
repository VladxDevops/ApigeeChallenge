+++
title = "Changelog — Apigee Challenge"
domain = "governance"
tier = 1
topics = ["changelog", "history", "tracking"]
parent = "README.md"
children = []
related = [
    "transcripts.md",
    "AGENTS.md",
    "AI_MANIFEST.toml"
]
updated_by = "Antigravity AI"
version = "1.3"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Agent Transcripts**: [`transcripts.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/transcripts.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Chronological record of meaningful architectural and IaC changes to the Apigee Challenge repository.
- Questions Answered: What changed recently? When was a decision made? What was the reason for a change?
- When to Retrieve: Auditing project history, understanding the evolution of a decision, or writing a new entry.
- When NOT to Retrieve: When reading current architecture or security model — those are canonical, not historical.
-->

# Changelog

## 2026-09-18 — Subnet Rightsizing & GCP Minimum Requirements Alignment

- Rightsized API spoke subnets from wasteful `/24` (256 IPs each, 768 IPs total) to the bare minimum required by GCP platform constraints and challenge workloads:
  - `regional_proxy_only`: `/26` (64 IPs, 60 usable) — enforces GCP's hard minimum prefix limit for regional Envoy proxies (GCP rejects masks longer than `/26`).
  - `psc_nat`: `/29` (8 IPs, 4 usable) — aligns with GCP's platform minimum for PSC published service NAT and easily covers Apigee's southbound endpoint attachments.
  - `api_private`: `/28` (16 IPs, 12 usable) — lean allocation safely supporting internal load balancing and backend testing without address exhaustion.
- Consolidated all three active subnets within `10.80.0.0/25` (88 allocated IPs total, an 88.5% reduction), conserving enterprise IPAM address space.
- Updated Terraform declarations in `platform/GCP/terraform/modules/infrastructure/networking.tf`, root `variables.tf`, and infrastructure module `variables.tf`.
- Updated documentation in `docs/networking/addressing-plan.md`, `docs/architecture/architecture.md`, and `docs/decisions/architecture-decisions.md`.
- Reason: User requested removing over-provisioned /24 CIDRs and sizing subnets to the bare minimum required for the challenge and by GCP services.
- Validation: `terraform fmt -check` and `terraform validate` executed successfully.

## 2026-09-17 — Progressive Disclosure Applied to All Documents


- Applied TOML front matter, breadcrumbs, and AI retrieval hints to all 24 target `.md` files.
- Empty stub files (`platform/GCP/terraform/modules/infrastructure/README.md`, `platform/GCP/terraform/modules/infrastructure/Agents.md`, `Agents/skills/agents.md`) were populated with minimal content.
- Skipped: `internalDocumentation/README.md` (already complete), skill-internal files.
- Reason: Enforce machine-friendly context architecture per Progressive Disclosure SKILL.md v2.1.0.
- Validation: `validate_metadata.py` run after edits.

## 2026-09-17 — Apigee architecture and deployment planning

- Updated the public README status and selected-design summary.
- Replaced placeholder deliverable documents for traffic flows, decisions, addressing, assumptions, and deployment validation.
- Added `docs/networking/network-architecture.md` to map the selected design to network resources and deployment order.
- Rewrote the security model to align with Apigee non-VPC-peering, PSC, Cloud Run, Cloud Armor, Secret Manager, and least-privilege IAM.
- Cleaned the Terraform infrastructure scaffold by replacing placeholder network syntax with a minimal API spoke VPC, private subnet, regional proxy-only subnet, and PSC NAT subnet.
- Reason: The challenge brief requires a defensible, reproducible GCP/Apigee design with private connectivity and documented assumptions.
- Validation: Documentation reviewed against `Challenge/challenge.md` and official Google Cloud / Apigee documentation; Terraform formatting/validation run after edits.

## 2026-09-14 — Repository bootstrap

- Created the multi-agent project structure.
- Added `AGENTS.md` as the primary agent operating contract.
- Added public/external documentation hierarchy.
- Added Git-ignored internal documentation hierarchy.
- Added initial `.gitignore`.
- Added starter README.

## 2026-09-16 — Progressive Disclosure Skill Implementation

- Instantiated Project-Level Progressive Disclosure Skill under `internalDocumentation/skills/progressive-disclosure/` (aliased at `internalDocumentation/SKILL.md` and `Agents/skills/Progressive-Disclosure/`).
- Deployed universal knowledge hierarchy guide (`references/universal-hierarchy-apigee.md`) mapping all project documentation across 4 progressive disclosure tiers.
- Deployed role-based context ingestion matrix (`references/context-ingestion-matrix.md`) enforcing token budgets and preventing context dilution.
- Deployed drop-in document metadata and header templates (`examples/document-header-templates.md`).
- Established machine control plane `AI_MANIFEST.toml` at repository root and inside skill examples (`examples/AI_MANIFEST_APIGEE.toml`).
- Created automated metadata and link validator CLI (`scripts/validate_metadata.py`).
- Added internal documentation catalog (`internalDocumentation/README.md`).
- Updated challenge requirements reference path to `Challenge/challenge.md` across all skill files and manifests.
- Integrated comprehensive image analysis of `Challenge/FullView.png` and related schematics directly into `Challenge/challenge.md` under section '2. Punto de partida'.

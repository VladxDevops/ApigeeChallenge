+++
title = "Agent Operating Contract — Apigee Challenge"
domain = "governance"
tier = 1
topics = ["agents", "governance", "rules", "multi-agent", "operating-contract"]
parent = "README.md"
children = []
related = [
    "README.md",
    "AI_MANIFEST.toml",
    "Challenge/challenge.md",
    "Agents/skills/Progressive-Disclosure/SKILL.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Requirements**: [`Challenge/challenge.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/Challenge/challenge.md)
> **Related**: [`changelog.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/changelog.md) | [`transcripts.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/transcripts.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Primary operating contract for all AI agents and human developers working on this repository.
- Questions Answered: What are the non-negotiable constraints? What are the agent rules? What is the source-of-truth hierarchy? What is the required documentation structure?
- When to Retrieve: At the start of any session, before making architectural decisions, or before modifying any document structure.
- When NOT to Retrieve: When executing a specific, already-decided implementation task with no architectural ambiguity.
-->

# AGENTS.md — Cloud Engineer DevOps Technical Exercise

## 0. Purpose

This repository is a dedicated, from-scratch project for the Rocket Code Cloud Engineer / Cloud Architect technical evaluation.

The project must produce a **clear, viable, reproducible GCP architecture and Infrastructure-as-Code implementation** for the API exposure and private-connectivity scenario described by the company.

Multiple AI agents may work on this repository, including VS Code agents, Antigravity agents, Codex, and other coding assistants. This file is the **primary operating contract** for all agents.

The agents must optimize for:

1. Correctness.
2. Security.
3. Reproducibility with Terraform.
4. Clear architectural reasoning.
5. Defensible oral-exam decisions.
6. Minimal but sufficient implementation.
7. Progressive disclosure of documentation.
8. Traceability of important decisions and changes.

Do not optimize for unnecessary complexity, excessive code, or producing a large amount of documentation that does not strengthen the technical defense.

---

# 1. Evaluation Context

The exercise concerns:

- A new API platform project ("spoke").
- A provider-managed API runtime located outside the organization's VPC.
- A new VPC dedicated to the API project.
- An externally reachable entry point protected by a WAF.
- A central existing network hub / VPC.
- Existing on-premises business systems.
- Private connectivity between the new API platform and the existing internal environment.
- New application services / containers managed by the organization.
- Security, routing, IAM, TLS, secrets, and infrastructure-as-code.

The central design problem is the area explicitly marked in the supplied architecture diagram:

> How traffic enters the managed API runtime.
>
> How traffic returns toward private backends.
>
> Which private-connectivity mechanisms are used.
>
> Which special subnets are required.
>
> Where traffic transitions into the internal network.

The architecture must respect the company's explicit constraints.

---

# 2. Non-Negotiable Constraints

Agents MUST NOT design a solution that:

- Exposes backends directly to the public internet.
- Assigns organization-owned IP addresses to the provider-managed runtime.
- Assumes the provider-managed runtime can directly route to arbitrary private customer CIDRs.
- Solves transitively by adding unauthorized / unnecessary VPC peerings.
- Creates overlapping CIDR ranges with existing organizational networks.
- Requires manual configuration for infrastructure that should be reproducible.
- Treats the provider-managed runtime as if it were an ordinary subnet inside the organization's VPC.
- Invents unsupported GCP capabilities.
- Hides important assumptions.

Every architectural proposal must explicitly demonstrate compliance with these constraints.

---

# 3. Source-of-Truth Hierarchy

When making decisions, use this precedence:

1. **Company-provided exercise instructions**
2. **Official Google Cloud documentation**
3. **Official documentation from the selected API-management/provider technology**
4. **Terraform provider documentation**
5. **Repository decisions and ADRs**
6. **Secondary technical references**
7. **AI-generated suggestions**

AI agents must never treat an AI suggestion as authoritative when it conflicts with official documentation.

When a technical capability is uncertain, mark it as `UNVERIFIED` and investigate it before implementing it.

---

# 4. Working Principles

## 4.1 Architecture before implementation

Do not start by writing Terraform.

First establish:

1. Requirements.
2. Constraints.
3. Assumptions.
4. Traffic flows.
5. Trust boundaries.
6. Network boundaries.
7. Candidate connectivity patterns.
8. Decision criteria.
9. Selected architecture.
10. Addressing plan.
11. Security model.
12. Terraform implementation.

Terraform implements the architecture; it does not define the architecture accidentally.

## 4.2 Prefer managed services

Prefer GCP managed services where they materially improve:

- Security.
- Reliability.
- Operability.
- Reproducibility.
- Cost transparency.
- Reduction of operational burden.

Do not select a managed service merely because it is available.

## 4.3 Minimize moving parts

The company explicitly states that an extensive solution is not required.

Use the smallest architecture that convincingly satisfies:

- Private connectivity.
- Security.
- API exposure.
- On-premises reachability.
- Application-backend reachability.
- Terraform reproducibility.

If two designs satisfy the requirements, prefer the simpler one unless the more complex design has a clearly documented operational/security advantage.

## 4.4 Every major decision must be defensible

For every major architecture decision, document:

- Decision.
- Problem being solved.
- Alternatives considered.
- Why alternatives were rejected.
- Selection criteria.
- Consequences.
- Risks.
- Operational impact.
- Security impact.
- Cost impact where relevant.

The final oral defense must be possible without referring to the repository.

---

# 5. Progressive Disclosure

Documentation MUST use progressive disclosure.

Do not put every implementation detail into the top-level documents.

Use this hierarchy:

### Level 1 — Executive / reviewer view

Documents intended for a technical evaluator who needs to understand the architecture quickly.

Examples:

- `README.md`
- Architecture diagram.
- Executive architecture summary.
- Decision summary.

### Level 2 — Engineering design

Documents needed to understand why the system was designed this way.

Examples:

- Architecture decisions.
- Network design.
- Security model.
- Traffic flows.
- Addressing plan.
- Assumptions and risks.

### Level 3 — Implementation

Documents needed to deploy or modify the system.

Examples:

- Terraform module documentation.
- Environment documentation.
- CI/CD documentation.
- Validation procedures.
- Runbooks.

### Level 4 — Internal working material

Temporary or sensitive working information that is useful to agents but should NOT be part of the public submission.

Examples:

- Agent transcripts.
- Investigation notes.
- Scratch analysis.
- Local environment notes.
- Credentials or credential references.
- Debug output.
- Unpublished alternatives.
- Internal review notes.

Internal documentation belongs under `docs/internal/` and MUST be ignored by Git.

---

# 6. Required Repository Documentation

The repository MUST maintain:

## Public / external documentation

These are safe to provide to the company as part of the submission:

```text
README.md

docs/
├── architecture/
│   ├── architecture.md
│   ├── traffic-flows.md
│   └── diagrams/
├── decisions/
│   └── architecture-decisions.md
├── networking/
│   └── addressing-plan.md
├── security/
│   └── security-model.md
├── operations/
│   └── deployment-and-validation.md
└── assumptions/
    └── assumptions-risks-tradeoffs.md
```

The exact hierarchy may evolve, but the concepts must remain discoverable.

## Internal documentation

Internal material MUST be placed below:

```text
docs/internal/
```

Examples:

```text
docs/internal/
├── research/
├── agent-notes/
├── investigations/
├── alternatives/
├── reviews/
└── scratch/
```

`docs/internal/` MUST be added to `.gitignore`.

Do not place credentials, private keys, service-account JSON files, access tokens, or other secrets in the repository even if `docs/internal/` is ignored.

---

# 7. Required Tracking Files

## changelog.md

Maintain:

```text
changelog.md
```

Record meaningful repository changes.

Each meaningful entry should contain:

- Date.
- Agent or contributor if known.
- Change.
- Reason.
- Affected area.
- Validation performed.

Do not record every trivial formatting change.

## transcripts.md

Maintain:

```text
transcripts.md
```

Use this as a lightweight index / record of significant AI-agent work.

Each entry should contain:

- Date/time.
- Agent/tool.
- Objective.
- Important findings.
- Decisions influenced.
- Files changed.
- Validation performed.
- Outstanding questions.

Do not dump massive model conversations into the file. Summarize them.

Detailed or sensitive agent notes belong in:

```text
docs/internal/agent-notes/
```

and remain Git-ignored.

---

# 8. Repository Structure

Use a structure similar to:

```text
.
├── AGENTS.md
├── README.md
├── changelog.md
├── transcripts.md
├── .gitignore
│
├── docs/
│   ├── architecture/
│   │   ├── architecture.md
│   │   ├── traffic-flows.md
│   │   └── diagrams/
│   │       ├── architecture-source/
│   │       └── rendered/
│   │
│   ├── decisions/
│   │   └── architecture-decisions.md
│   │
│   ├── networking/
│   │   └── addressing-plan.md
│   │
│   ├── security/
│   │   └── security-model.md
│   │
│   ├── operations/
│   │   └── deployment-and-validation.md
│   │
│   ├── assumptions/
│   │   └── assumptions-risks-tradeoffs.md
│   │
│   └── internal/
│       ├── research/
│       ├── agent-notes/
│       ├── investigations/
│       ├── alternatives/
│       ├── reviews/
│       └── scratch/
│
├── terraform/
│   ├── modules/
│   └── environments/
│       └── <environment>/
│
├── scripts/
│
└── tests/
    ├── terraform/
    ├── networking/
    └── validation/
```

Do not create all directories merely for appearance. Create files/directories when they become useful, but preserve the conceptual hierarchy.

---

# 9. Terraform Rules

Terraform is the Infrastructure-as-Code source of truth.

Agents MUST:

- Avoid manual cloud-console configuration for resources managed by Terraform.
- Use variables rather than hard-coded environment-specific values.
- Keep reusable modules separate from environment configuration.
- Make dependencies explicit.
- Use remote state appropriately when the implementation requires it.
- Document provider versions.
- Pin important provider/module versions when practical.
- Use least privilege for deployment identities.
- Run formatting and validation.
- Review Terraform plans before applying.
- Avoid committing state files or credentials.

At minimum, implementation work should consider:

```text
terraform fmt
terraform init
terraform validate
terraform plan
```

Additional static/security validation should be introduced where useful.

Never run `terraform apply` against an unknown or production environment without explicit authorization.

---

# 10. GCP Design Rules

The design must explicitly reason about:

- VPC topology.
- Subnets.
- CIDR allocation.
- Routing.
- Firewall policy.
- Private service connectivity.
- Hybrid connectivity.
- DNS.
- Load balancing / ingress where applicable.
- WAF.
- API gateway / API management layer.
- Provider-managed runtime boundaries.
- On-premises connectivity.
- IAM.
- Service accounts.
- Secret Manager.
- TLS certificates.
- Logging.
- Monitoring.
- Auditability.

Do not assume that "private" automatically means "secure".

For every private path, explain:

- Who can initiate traffic.
- Destination.
- Addressing.
- Routing.
- Authentication.
- Authorization.
- Encryption.
- Firewall controls.
- Failure behavior.

---

# 11. Traffic-Flow Method

For every important flow, document the complete path.

Use a structure like:

```text
Source
  ↓
Entry / control
  ↓
API management layer
  ↓
Connectivity mechanism
  ↓
Destination network
  ↓
Backend
  ↓
Response path
```

For each hop identify:

- Network boundary.
- Trust boundary.
- Source IP semantics.
- Destination IP semantics.
- Protocol/port.
- Encryption.
- Authentication.
- Authorization.
- Routing dependency.
- Security control.

At minimum analyze:

1. External client → API platform.
2. API platform → cloud application backend.
3. API platform → on-premises backend.
4. Backend → API platform response.
5. Administrative/operator access.
6. Monitoring/logging path where relevant.

---

# 12. Provider-Managed Runtime Rule

Treat the provider-managed runtime as an external trust/network boundary unless official documentation proves otherwise.

Do not model it as a normal VM or subnet inside the customer's VPC.

Before selecting the connectivity design, verify:

- How the runtime receives traffic.
- Whether it supports private ingress.
- How it reaches private backends.
- What source addresses are used.
- Whether private connectivity requires a dedicated attachment, endpoint, proxy, load balancer, or other managed mechanism.
- Whether return traffic is supported.
- What DNS behavior is required.
- What subnet ranges are reserved or consumed.
- What the provider controls versus what the customer controls.

Document these findings.

---

# 13. Security Model

The final design must cover at least:

### Authentication

Determine how clients authenticate to APIs.

Examples may include:

- OAuth 2.0 / OIDC.
- JWT validation.
- mTLS.
- API keys where justified.

Do not select authentication mechanisms without considering the client type and threat model.

### Authorization

Define:

- API-level authorization.
- Application/service authorization.
- IAM permissions.
- Service-account permissions.
- Administrative roles.

Use least privilege.

### TLS

Define:

- External TLS termination.
- Internal TLS.
- Certificate ownership.
- Certificate lifecycle.
- Encryption in transit.
- mTLS if justified.

### Secrets

Use Secret Manager or an equivalent managed secret mechanism.

Never commit:

- Passwords.
- Private keys.
- Tokens.
- Service-account private keys.
- API secrets.

### IAM

Use:

- Dedicated service accounts.
- Least privilege.
- Separation of deployment and runtime identities.
- Avoidance of broad primitive roles when possible.

---

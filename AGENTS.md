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

# 14. Network Addressing Rules

The exercise explicitly forbids CIDR overlap.

Before choosing ranges:

1. Declare the assumed existing ranges.
2. Declare the new ranges.
3. Demonstrate that they do not overlap.
4. Explain subnet purpose.
5. Explain subnet sizing.
6. Explain reserved ranges required by selected GCP/provider services.
7. Explain future growth where relevant.

Do not invent an existing network inventory and then silently treat it as real.

Label assumptions clearly.

Example:

```text
ASSUMPTION:
Existing organization network uses 10.20.0.0/16.

PROPOSED:
API VPC uses 10.80.0.0/16.

STATUS:
Non-overlapping under the stated assumption.
```

The final addressing table should include:

| Network | CIDR | Size | Purpose | Region | Notes |
|---|---|---:|---|---|---|
| ... | ... | ... | ... | ... | ... |

---

# 15. Architecture Decision Process

For important choices, use a decision matrix.

Example:

| Option | Security | Connectivity | Complexity | Cost | Operational burden | Result |
|---|---|---|---|---|---|---|
| Option A | ... | ... | ... | ... | ... | Reject |
| Option B | ... | ... | ... | ... | ... | Select |
| Option C | ... | ... | ... | ... | ... | Reject |

At least five substantive decisions are expected because the company requests a minimum of five decisions in E2.

Likely decision categories include:

1. API runtime connectivity pattern.
2. External ingress / WAF architecture.
3. Private cloud-to-on-prem connectivity.
4. Network topology and routing.
5. Addressing/subnet strategy.
6. Backend exposure model.
7. Authentication/authorization.
8. TLS strategy.
9. Secret management.
10. Terraform/module/environment strategy.

The final list must reflect the actual selected architecture, not artificially create decisions to reach a number.

---

# 16. Required Company Deliverables

The implementation should support the following evaluation deliverables.

## E1 — Architecture Diagram

Format:

- PNG or PDF.

Must show:

- Complete end-to-end flow.
- Traffic direction.
- Network boundaries.
- Trust boundaries.
- External clients.
- WAF / external entry point.
- API VPC.
- Provider-managed runtime.
- Connectivity mechanism.
- Hub VPC.
- Cloud application platform.
- On-premises core systems.
- Relevant routing/private connectivity.
- Important security controls.

## E2 — Decision Document

Target:

- 4–8 pages.

Minimum:

- 5 decisions.
- Alternatives evaluated.
- Selection criteria.
- Selected solution.
- Consequences/trade-offs.

## E3 — Addressing Plan

Provide a clear subnet/range table with:

- CIDR.
- Size.
- Purpose.
- Region.
- Special/reserved ranges where applicable.

## E4 — Security Model

Include:

- Authentication.
- Authorization.
- TLS.
- Secrets.
- IAM.

## E5 — Assumptions, Risks and Trade-offs

Explicitly list:

- Assumptions.
- Risks.
- Mitigations.
- Trade-offs.
- Unverified dependencies.

---

# 17. Acceptance Criteria

Before considering the solution complete, verify:

## Architecture

- [ ] Full traffic flow is understandable from the diagram.
- [ ] Provider-managed runtime boundary is explicit.
- [ ] Trust boundaries are explicit.
- [ ] No backend is directly exposed to the internet.
- [ ] Private connectivity path is explicit.
- [ ] Return traffic is addressed.
- [ ] Hub-and-spoke constraints are respected.
- [ ] No unauthorized transitive VPC peering is introduced.

## Networking

- [ ] CIDRs do not overlap under documented assumptions.
- [ ] Subnet purposes are documented.
- [ ] Routing is documented.
- [ ] DNS requirements are documented.
- [ ] Special/reserved ranges are identified.
- [ ] On-premises routing is addressed.

## Security

- [ ] Authentication is defined.
- [ ] Authorization is defined.
- [ ] TLS is defined.
- [ ] Secrets are managed securely.
- [ ] IAM uses least privilege.
- [ ] Administrative access is controlled.
- [ ] Logging/auditing is considered.

## Infrastructure as Code

- [ ] Infrastructure is reproducible.
- [ ] Terraform is the source of truth.
- [ ] No secret material is committed.
- [ ] Terraform formatting/validation succeeds.
- [ ] Plan output has been reviewed.
- [ ] Important assumptions are represented as variables/configuration where appropriate.

## Documentation

- [ ] README provides the high-level entry point.
- [ ] Architecture documentation exists.
- [ ] Decision documentation exists.
- [ ] Addressing plan exists.
- [ ] Security model exists.
- [ ] Assumptions/risks/trade-offs exist.
- [ ] `changelog.md` is maintained.
- [ ] `transcripts.md` is maintained.
- [ ] Internal documentation is under `docs/internal/`.
- [ ] `docs/internal/` is ignored by Git.

## Oral Defense

An engineer should be able to explain, without AI assistance:

- Why this architecture was selected.
- Why alternative connectivity patterns were rejected.
- How traffic enters the system.
- How the provider runtime reaches private backends.
- How return traffic works.
- How on-premises systems are reached.
- Why CIDRs were selected.
- Why the security controls are sufficient.
- What happens when a connectivity component fails.
- What the major trade-offs are.
- How Terraform reproduces the environment.

---

# 18. AI Agent Operating Procedure

Every agent should follow this sequence.

### Phase 1 — Discover

Read:

1. `AGENTS.md`
2. `README.md` if present
3. Relevant public documentation
4. Relevant Terraform files
5. Relevant internal notes if explicitly needed

Do not immediately modify files.

### Phase 2 — Understand

Identify:

- Current architecture.
- Requirements.
- Constraints.
- Existing decisions.
- Open questions.
- Unverified assumptions.

### Phase 3 — Plan

Before making significant changes, state internally:

- What is being changed?
- Why?
- Which requirements does it satisfy?
- Which files will change?
- How will it be validated?

### Phase 4 — Implement

Make the smallest coherent change.

Avoid unrelated refactoring.

### Phase 5 — Validate

Run appropriate checks.

For Terraform, normally:

```text
terraform fmt
terraform validate
terraform plan
```

For documentation:

- Check consistency with the architecture.
- Check that diagrams and text agree.
- Check that no unsupported claims remain.

### Phase 6 — Document

Update:

- Relevant documentation.
- `changelog.md`.
- `transcripts.md`.

Put detailed working notes in `docs/internal/`.

### Phase 7 — Report

The agent's completion summary should contain:

```text
SUMMARY
- What changed.

WHY
- Why the change was necessary.

FILES
- Files added/modified.

VALIDATION
- Commands/checks performed.

ASSUMPTIONS
- New assumptions introduced.

RISKS / OPEN QUESTIONS
- Remaining uncertainties.

NEXT STEP
- Recommended next action.
```

---

# 19. Do Not Guess

When information is missing:

1. Determine whether it is actually required.
2. If not required, make a reasonable documented assumption.
3. If required for correctness, mark it `OPEN QUESTION` or `UNVERIFIED`.
4. Investigate using authoritative documentation.
5. Do not silently invent platform capabilities.

The exercise explicitly allows assumptions. Use them deliberately and document them.

---

# 20. Diagram Rules

The architecture diagram is an evaluation artifact, not decoration.

Use consistent visual semantics.

Recommended:

- Solid boundary = controlled environment.
- Dashed boundary = external / provider-controlled environment.
- Solid arrow = traffic path.
- Dashed arrow = logical dependency or control-plane relationship.
- Different labels for data plane and control plane.
- Explicit trust-boundary labels.
- Explicit network-boundary labels.

Every arrow should answer:

- Who initiates?
- Where does traffic go?
- Over what protocol?
- Through what security/control point?

Avoid arrows that merely mean "related to".

---

# 21. Public vs Internal Information

Before committing documentation, ask:

> Would the company expect this information in the submitted technical exercise?

Public documentation may contain:

- Architecture.
- Design decisions.
- Assumptions.
- CIDR examples.
- Security model.
- Terraform structure.
- Deployment instructions.
- Validation evidence.

Internal documentation may contain:

- Agent reasoning logs.
- Temporary hypotheses.
- Failed experiments.
- Private environment details.
- Local usernames/paths.
- Debug logs.
- Unpublished alternatives.
- Notes that are not ready for submission.

Never put secrets into either category.

---

# 22. Current Project Status

Initial status:

```text
PROJECT: New
IMPLEMENTATION: Not started
ARCHITECTURE: To be designed
TERRAFORM: To be designed
DOCUMENTATION: Repository bootstrap
```

The architecture must be derived from the company requirements and verified against current official GCP/provider documentation before implementation.

---

# 23. Important Initial Questions

Before locking the design, investigate these questions:

1. What exact API-management/runtime product is intended by the exercise?
2. What private connectivity mechanism does that runtime officially support?
3. Can the runtime initiate connections to private customer backends?
4. What source IP/range does the runtime use?
5. What destination IP/range must the customer expose internally?
6. What GCP subnet or reserved range is required by the selected connectivity mechanism?
7. How does the selected mechanism integrate with the existing hub VPC?
8. How does routing work between the new spoke VPC, hub VPC, and on-premises network?
9. Does the architecture require Cloud VPN, Cloud Interconnect, Private Service Connect, internal load balancing, proxying, or another mechanism?
10. What DNS resolution model is required?
11. What WAF/edge service should be used?
12. What authentication model is appropriate for external clients?
13. What authentication model should the API runtime use toward private backends?
14. How will certificates be issued and rotated?
15. Which IAM identities are needed for Terraform, runtime services, and deployment?
16. What exact existing CIDRs must be treated as unavailable?
17. What region(s) should be selected and why?
18. What HA/failure requirements should be assumed?
19. What is the minimum implementation necessary to prove the architecture?
20. What evidence should be collected for the oral defense?

Do not block the project waiting for every answer. Resolve what can be resolved from authoritative documentation and document reasonable assumptions for the rest.

---

# 24. Final Quality Gate

The project is ready for submission only when the architecture can be explained as one coherent story:

```text
External Client
    ↓
Secure Internet Entry / WAF
    ↓
API Management Boundary
    ↓
Provider-Managed Runtime
    ↓
Private Connectivity Mechanism
    ↓
Customer-Controlled Network
    ↓
Hub VPC / Hybrid Connectivity
    ↓
Cloud and/or On-Premises Backend
```

The actual implementation may differ from this conceptual sequence. The final design must show the exact selected path and justify every significant component.

The strongest submission is not the one with the most services.

It is the one where every service exists for a reason, every network path is explainable, every security boundary is deliberate, and the entire environment can be reproduced with Terraform.

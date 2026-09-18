+++
title = "Architecture Decision Records — Apigee Challenge"
domain = "decisions"
tier = 2
topics = ["adr", "decisions", "apigee", "non-vpc-peering", "psc", "trade-offs", "rationale"]
parent = "README.md"
children = []
related = [
    "docs/architecture/architecture.md",
    "docs/assumptions/assumptions-risks-tradeoffs.md",
    "Challenge/challenge.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Architecture**: [`architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/architecture.md)
> **Assumptions**: [`assumptions-risks-tradeoffs.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/assumptions/assumptions-risks-tradeoffs.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Formal Architecture Decision Records (ADRs) documenting why specific technology and design choices were made.
- Questions Answered: Why Non-VPC-Peering over VPC Peering? Why PSC and not a public endpoint? Why Cloud Run over GKE?
- When to Retrieve: Justifying decisions to evaluators, resolving architectural ambiguity, or understanding the reasoning behind a specific design choice.
- When NOT to Retrieve: When the current architecture state is needed (use architecture.md) or implementation details (use CloudRun-requirements.md).
-->

# Architecture Decisions

This document records the major decisions needed to defend the proposed architecture.


## Decision 1 - API Runtime Product

**Decision:** Use Google Cloud Apigee.

| Option | Security | Connectivity | Complexity | Result |
|---|---|---|---|---|
| Apigee | Strong API policy layer, analytics, OAuth/JWT support | Supports PSC patterns for managed runtime connectivity | Moderate | Selected |

| API Gateway | Simpler gateway | Less aligned with the interview signal and managed-runtime diagram | Low | Rejected |
| Self-managed gateway on GKE | Flexible | Adds unnecessary runtime ownership | High | Rejected |

**Reason:** The role explicitly values GCP and Apigee experience, and the challenge is framed around a provider-managed runtime outside the customer VPC.


## Decision 2 - Apigee Networking Model

**Decision:** Use Apigee non-VPC-peering networking.

| Option | Security | Connectivity | Complexity | Result |
|---|---|---|---|---|
| Non-VPC peering with PSC | Keeps Apigee outside customer VPC and avoids customer CIDR assignment | PSC northbound and southbound | Moderate | Selected |

| VPC peering | Valid Apigee model, but requires Apigee instance CIDR allocations | Can create peering constraints | Moderate | Rejected |
| Treat Apigee as a customer subnet | Violates challenge constraints | Unsupported | Low on paper, invalid in reality | Rejected |

**Consequence:** The design must provision PSC-facing load-balancing/service-attachment resources and must not rely on arbitrary private routing from Apigee into customer CIDRs.


## Decision 3 - External Entry and WAF

**Decision:** Use a regional external Application Load Balancer in `us-south1` with Cloud Armor.

| Option | Security | Connectivity | Complexity | Result |
|---|---|---|---|---|
| Regional external Application Load Balancer + Cloud Armor | WAF at edge, regional alignment | Supports PSC backend pattern | Moderate | Selected |

| Global external Application Load Balancer | Strong global edge | More than needed for single-region exercise | Moderate | Deferred |
| Direct Apigee public endpoint only | Simplifies edge | Weakens explicit WAF entry requirement | Low | Rejected |

**Consequence:** A regional proxy-only subnet is required for Envoy-based regional load balancing.


## Decision 4 - Southbound Private Connectivity

**Decision:** Publish private backend targets through customer PSC service attachments and connect Apigee using endpoint attachments.

| Option | Security | Connectivity | Complexity | Result |
|---|---|---|---|---|
| PSC endpoint attachment to service attachment | Private, explicit producer/consumer boundary | Official Apigee southbound pattern | Moderate | Selected |

| Direct route from Apigee to private CIDRs | Not allowed by challenge | Unsupported assumption | Low, invalid | Rejected |
| Public backend URL with IP restrictions | Exposes backend to Internet path | Avoids PSC but violates spirit of private backend | Low | Rejected |

**Consequence:** Producer-side load balancing and a PSC NAT subnet are required before Apigee endpoint attachments can become active.


## Decision 5 - Cloud Application Runtime

**Decision:** Use Cloud Run for the new application services.

| Option | Security | Operations | Complexity | Result |
|---|---|---|---|---|

| Cloud Run | Managed containers, minimal operations | Fits exercise scope | Low | Selected |
| GKE | Highly flexible | Operationally heavy for this challenge | High | Rejected |
| Compute Engine MIG | Familiar networking | More patching and instance management | Moderate | Rejected |

**Consequence:** Cloud Run ingress must be restricted so it cannot become a direct Internet bypass around Apigee.


## Decision 6 - Hybrid Connectivity

**Decision:** Use existing Hub VPC plus HA Cloud VPN as the baseline path to on-premises.

| Option | Security | Performance | Complexity | Result |
|---|---|---|---|---|
| HA Cloud VPN | Encrypted private connectivity | Good enough for exercise | Moderate | Selected |

| Dedicated/Partner Interconnect | Better deterministic throughput | Requires more assumptions and provisioning | High | Deferred |
| Public access to on-premises services | Not acceptable | Internet exposed | Low, invalid | Rejected |

**Consequence:** The design must explicitly document route advertisements, return routes, and firewall rules between API VPC, Hub VPC, and on-premises.


## Decision 7 - Addressing Strategy

**Decision:** Use a new non-overlapping API VPC block in `10.80.0.0/16`, subject to validation against the real network inventory.

| Option | Benefit | Risk | Result |
|---|---|---|---|
| `10.80.0.0/16` for API VPC | Clear separation from assumed existing ranges | Must verify with actual IPAM | Selected assumption |
| Reuse Hub ranges | Saves address space | Overlap and blast-radius risk | Rejected |
| Use provider/runtime CIDRs | Violates non-VPC-peering intent | Invalid | Rejected |

**Consequence:** The final plan must label existing ranges as assumptions until confirmed by the company.

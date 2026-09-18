+++
title = "Assumptions, Risks and Trade-offs — Apigee Challenge"
domain = "assumptions"
tier = 2
topics = ["assumptions", "risks", "trade-offs", "constraints", "apigee", "gcp"]
parent = "README.md"
children = []
related = [
    "docs/decisions/architecture-decisions.md",
    "docs/architecture/architecture.md",
    "Challenge/challenge.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Architecture Decisions**: [`architecture-decisions.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/decisions/architecture-decisions.md)
> **Requirements**: [`challenge.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/Challenge/challenge.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Documents the assumptions made, risks identified, and trade-offs accepted during design of the Apigee Challenge architecture.
- Questions Answered: What assumptions are we making about the evaluator's environment? What are the known risks? What did we trade off and why?
- When to Retrieve: Risk review, audit of design rationale, or when unknown requirements need to be surfaced.
- When NOT to Retrieve: When the formal ADRs are needed (use architecture-decisions.md) or current architecture (use architecture.md).
-->

# Assumptions, Risks and Trade-offs

## Assumptions

| Assumption | Impact if Wrong | Mitigation |
|---|---|---|
| Primary region is `us-south1`. | Some Apigee/GCP resources might not be available or quota-ready. | Verify service availability and quotas before final plan. |
| The company expects Apigee knowledge, so Apigee is the selected API runtime. | A different runtime would alter PSC details. | Document Apigee as a deliberate decision. |
| Apigee should use non-VPC-peering networking. | VPC peering would require different CIDRs and provisioning. | Validate against official Apigee docs and challenge constraints. |
| Hub VPC uses `10.20.0.0/16`. | Addressing plan could overlap real networks. | Replace with real IPAM values before deployment. |
| On-premises uses `10.0.0.0/12`. | Route overlap could break hybrid traffic. | Confirm with network team. |
| HA Cloud VPN is sufficient for the exercise. | Production latency/throughput might require Interconnect. | Treat Interconnect as a production follow-up option. |
| Cloud Run is acceptable for the new container platform. | If stateful or low-level networking is required, design may change. | Keep GKE as a rejected/deferred alternative. |

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Apigee endpoint attachment or non-VPC-peering provisioning may require specific permissions or CLI/API steps. | High | Validate provider/API support before final automation. |
| Southbound PSC service attachment must target a supported producer load-balancing pattern. | High | Build a minimal proof with Cloud Run/backend load balancing before claiming complete deployment. |
| Hub-to-spoke route propagation may not exist in the real environment. | High | Mark the hub integration as an external dependency and document required routes. |
| On-premises peak latency remains high. | Medium | Use Apigee, LB, Cloud Run, VPN, and application telemetry to locate latency; do not claim LB solves database latency. |
| Terraform IAM bootstrap may require temporary elevated permissions. | Medium | Use a bootstrap identity, then reduce day-2 permissions. |
| Public Cloud Run default URL could bypass Apigee if ingress is not restricted. | High | Set Cloud Run ingress to internal/load-balancing path and validate direct access fails. |

## Trade-offs

| Trade-off | Benefit | Cost |
|---|---|---|
| Regional instead of multi-region design | Faster, simpler, easier to defend | Less resilient than a production multi-region architecture |
| Cloud VPN instead of Interconnect | Easier exercise deployment | Less predictable latency/throughput |
| Cloud Run instead of GKE | Lower operations burden | Less control over networking internals |
| PSC instead of VPC peering | Aligns with challenge constraints and avoids Apigee CIDR assignment | Requires explicit service attachments and endpoint attachments |
| Minimal Terraform modules | Easier to review for the interview | Less reusable than a mature platform module library |

## Open Questions

1. Exact production domain and certificate ownership.
2. Real Hub VPC and on-premises CIDR inventory.
3. Whether the existing Hub uses Shared VPC, Network Connectivity Center, VPC peering, or another approved spoke connection model.
4. Apigee organization type: evaluation, pay-as-you-go, or subscription.
5. Required API client authentication model for third parties.
6. Whether on-premises targets require mTLS, OAuth token exchange, basic auth migration, or another backend credential pattern.

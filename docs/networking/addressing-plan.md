+++
title = "IP Addressing Plan — Apigee Challenge"
domain = "networking"
tier = 2
topics = ["networking", "cidr", "ip", "addressing", "vpc", "subnets", "gcp"]
parent = "docs/networking/network-architecture.md"
children = []
related = [
    "docs/networking/network-architecture.md",
    "docs/architecture/architecture.md",
    "docs/architecture/traffic-flows.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`network-architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/network-architecture.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Architecture**: [`architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/architecture.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Proposed IP addressing and CIDR allocation plan for the Apigee Challenge GCP network.
- Questions Answered: What subnets are used? What are the PSC endpoint addresses? What CIDR ranges are allocated to each VPC?
- When to Retrieve: Writing Terraform networking code, reviewing firewall rules, debugging PSC connectivity, or verifying CIDR non-overlap.
- When NOT to Retrieve: When only the high-level network topology is needed (use network-architecture.md).
-->

# Addressing Plan

The challenge does not provide the organization's real IP inventory. The ranges below are proposed for the exercise and must be validated against actual IPAM before production use.

## Assumed Existing Ranges

| Network | CIDR | Status | Notes |
|---|---:|---|---|
| Existing Hub VPC | `10.20.0.0/16` | ASSUMPTION | Represents the central network hub from the challenge diagram. |
| On-premises core systems | `10.0.0.0/12` | ASSUMPTION | Represents data-center networks reachable through VPN. |
| Existing shared services | `10.40.0.0/16` | ASSUMPTION | Reserved to show non-overlap discipline. |

## Proposed New Ranges

| Network / Subnet | CIDR | Total IPs | Usable IPs | Purpose | Region | Owner | Notes |
|---|---:|---:|---:|---|---|---|---|
| API VPC supernet | `10.80.0.0/16` | 65,536 | — | New API spoke VPC address space | `us-south1` | Customer | Non-overlapping under stated assumptions. |
| API private services subnet | `10.80.0.0/28` | 16 IPs | 12 IPs | Private backend/ILB forwarding rules | `us-south1` | Customer | Regular subnet (lean /28 allocation). |
| PSC NAT subnet | `10.80.0.16/29` | 8 IPs | 4 IPs | Source NAT range for published PSC services | `us-south1` | Customer | `purpose = PRIVATE_SERVICE_CONNECT` (GCP minimum /29). |
| Serverless VPC connector subnet | `10.80.0.32/28` | 16 IPs | 12 IPs | Optional Cloud Run egress to private VPC targets | `us-south1` | Customer | Only create if Cloud Run needs direct VPC egress. |
| Regional proxy-only subnet | `10.80.0.64/26` | 64 IPs | 60 IPs | Envoy proxies for regional Application Load Balancers | `us-south1` | Customer | `purpose = REGIONAL_MANAGED_PROXY` (GCP minimum /26). |
| Unallocated / Spoke reserve | `10.80.0.128/25` | 128 IPs | — | Unallocated spare space in first `/24` | `us-south1` | Customer | Reserved for future spoke subnet expansion. |
| Future API expansion | `10.80.16.0/20` | 4,096 IPs | — | Reserved for additional private backends | `us-south1` | Customer | Do not allocate until needed. |

---

## Subnet Rightsizing & GCP Minimum Requirements Analysis

### Do We Need /24 (256 IPs) per Subnet?
**No.** Allocating `/24` (256 IPs) per subnet in a dedicated API spoke VPC is significant over-provisioning:
- Three `/24` subnets would consume **768 IP addresses** across three distinct third-octet blocks (`10.80.0.0/24`, `10.80.1.0/24`, `10.80.2.0/24`).
- For the Apigee challenge, the spoke VPC hosts only a regional load balancer entry point, a PSC service attachment, and internal forwarding rules/backends.
- By rightsizing the subnets to the **bare minimum required by GCP platform constraints**, total allocated address space drops from 768 IPs to **88 IPs** (an **88.5% reduction**).
- All three required subnets now fit compactly within the lower half of a single `/24` (`10.80.0.0/25`), preserving enterprise IPAM address space.

### GCP Platform Minimums & Sizing Rationale

| Subnet | Selected CIDR | Total IPs | Reserved by GCP | Usable IPs | GCP Platform Constraint | Challenge Sizing Rationale |
|---|---|---:|---:|---:|---|---|
| **Regional Proxy-Only** (`regional_proxy_only`) | `10.80.0.64/26` | 64 | 4 | 60 | **GCP Enforced Minimum: `/26`** (Google Cloud explicitly rejects prefix lengths longer than `/26`, such as `/27` or `/28`). | Envoy proxies for regional ALBs require `/26` minimum. 60 usable proxy IPs can handle tens of thousands of concurrent connections. |
| **PSC NAT Subnet** (`psc_nat`) | `10.80.0.16/29` | 8 | 4 | 4 | **GCP Enforced Minimum: `/29`** (Supported range is `/29` to `/16`). | In PSC, each connected consumer endpoint consumes 1 NAT IP. Apigee connects via 1-2 endpoint attachments, making `/29` (4 usable IPs) the exact bare minimum. |
| **API Private Subnet** (`api_private`) | `10.80.0.0/28` | 16 | 4 | 12 | **GCP Platform Minimum: `/29`** (VPC subnets support `/29` to `/8`). | `/29` only leaves 4 usable IPs (.2-.5). An ILB forwarding rule consumes 1 IP, leaving only 3. `/28` provides 12 usable IPs—lean, safe against IP exhaustion during backend testing, and saves 93.75% of IPs vs `/24`. |

### CIDR Boundary Alignment
- Subnets must align on binary network boundaries:
  - `10.80.0.0/28`: Spans `10.80.0.0` – `10.80.0.15` (16 IPs).
  - `10.80.0.16/29`: Spans `10.80.0.16` – `10.80.0.23` (8 IPs).
  - `10.80.0.24/29` & `10.80.0.32/27`: Unassigned / optional Serverless connector.
  - `10.80.0.64/26`: Spans `10.80.0.64` – `10.80.0.127` (64 IPs). Because a `/26` requires a 64-address boundary (`.0`, `.64`, `.128`, `.192`), placing it at `.64` guarantees strict RFC and GCP compliance with zero overlap.
  - `10.80.0.128/25`: Spans `10.80.0.128` – `10.80.0.255` (128 IPs, unallocated reserve).

---

## Apigee Runtime Addressing

For the selected non-VPC-peering model, the design does not allocate organization-owned `/22` or `/28` ranges to the Apigee runtime. Apigee remains provider-managed and outside the customer VPC boundary.

Southbound endpoint attachments may return a host IP used by Apigee proxies to reach the service behind a customer service attachment. That IP is an Apigee-side endpoint value and must not be treated as a customer subnet allocation.

## Non-Overlap Check

Under the documented assumptions:

- Proposed API VPC `10.80.0.0/16` does not overlap assumed Hub VPC `10.20.0.0/16`.
- Proposed API VPC `10.80.0.0/16` does not overlap assumed shared services `10.40.0.0/16`.
- Proposed API VPC `10.80.0.0/16` does not overlap assumed on-premises `10.0.0.0/12` because `10.0.0.0/12` covers `10.0.0.0` through `10.15.255.255`.
- All subnets within the API VPC are mathematically disjoint with verified zero internal overlap.

## Validation Required Before Deployment

1. Confirm the real Hub VPC CIDRs.
2. Confirm on-premises route advertisements and return-route expectations.
3. Confirm any organization-wide reserved ranges.
4. Confirm `us-south1` service availability for each selected GCP and Apigee feature.
5. Confirm PSC service attachment NAT subnet size against expected consumer attachment count (currently sized at `/29` for up to 4 consumer attachments).

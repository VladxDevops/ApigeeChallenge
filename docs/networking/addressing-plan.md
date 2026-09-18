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

| Network / Subnet | CIDR | Size | Purpose | Region | Owner | Notes |
|---|---:|---:|---|---|---|---|
| API VPC supernet | `10.80.0.0/16` | /16 | New API spoke VPC address space | `us-south1` | Customer | Non-overlapping under stated assumptions. |
| API private services subnet | `10.80.0.0/24` | 256 IPs | Private backend/proxy resources if VM or ILB-backed services are added | `us-south1` | Customer | Regular subnet. |
| Regional proxy-only subnet | `10.80.1.0/24` | 256 IPs | Envoy proxies for regional external/internal Application Load Balancers | `us-south1` | Customer | `purpose = REGIONAL_MANAGED_PROXY`. |
| PSC NAT subnet | `10.80.2.0/24` | 256 IPs | Source NAT range for published PSC services | `us-south1` | Customer | `purpose = PRIVATE_SERVICE_CONNECT`. |
| Serverless VPC connector subnet | `10.80.3.0/28` | 16 IPs | Optional Cloud Run egress to private VPC targets | `us-south1` | Customer | Only create if Cloud Run needs direct VPC egress. |
| Future API expansion | `10.80.16.0/20` | 4096 IPs | Reserved for additional private backends | `us-south1` | Customer | Do not allocate until needed. |

## Apigee Runtime Addressing

For the selected non-VPC-peering model, the design does not allocate organization-owned `/22` or `/28` ranges to the Apigee runtime. Apigee remains provider-managed and outside the customer VPC boundary.

Southbound endpoint attachments may return a host IP used by Apigee proxies to reach the service behind a customer service attachment. That IP is an Apigee-side endpoint value and must not be treated as a customer subnet allocation.

## Non-Overlap Check

Under the documented assumptions:

- Proposed API VPC `10.80.0.0/16` does not overlap assumed Hub VPC `10.20.0.0/16`.
- Proposed API VPC `10.80.0.0/16` does not overlap assumed shared services `10.40.0.0/16`.
- Proposed API VPC `10.80.0.0/16` does not overlap assumed on-premises `10.0.0.0/12` because `10.0.0.0/12` covers `10.0.0.0` through `10.15.255.255`.

## Validation Required Before Deployment

1. Confirm the real Hub VPC CIDRs.
2. Confirm on-premises route advertisements and return-route expectations.
3. Confirm any organization-wide reserved ranges.
4. Confirm `us-south1` service availability for each selected GCP and Apigee feature.
5. Confirm PSC service attachment NAT subnet size against expected consumer attachment count.

+++
title = "Network Architecture Plan — Apigee Challenge"
domain = "networking"
tier = 2
topics = ["networking", "vpc", "psc", "gcp", "terraform", "network-resources", "firewall"]
parent = "docs/architecture/architecture.md"
children = [
    "docs/networking/addressing-plan.md"
]
related = [
    "docs/architecture/architecture.md",
    "docs/architecture/traffic-flows.md",
    "docs/security/security-model.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/architecture.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **CIDR Details**: [`addressing-plan.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/addressing-plan.md)
> **Security**: [`security-model.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/security/security-model.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Translates the architecture into the exact GCP network resources (VPCs, subnets, PSC endpoints, firewall rules) that Terraform must provision.
- Questions Answered: What VPCs and subnets need to be created? Which forwarding rules are required? What firewall rules apply?
- When to Retrieve: Writing or reviewing Terraform networking modules, planning PSC service attachment configuration.
- When NOT to Retrieve: When only CIDR tables are needed (use addressing-plan.md) or high-level design flows (use traffic-flows.md).
-->

# Network Architecture Plan

This document translates the selected architecture into network resources that Terraform should provision or reference.

## Target Region

Primary region: `us-south1`

The design is regional for the exercise. Zonal resources are avoided unless a specific service requires them.

## Customer-Controlled API Spoke

Terraform should create or manage:

| Resource | Purpose |
|---|---|
| Custom-mode VPC `api-spoke-vpc` | Isolated API platform network. |
| Private services subnet | Space for private backend/proxy components if needed. |
| Proxy-only subnet | Required by regional Envoy-based Application Load Balancers. |
| PSC NAT subnet | Required when publishing services with Private Service Connect. |
| Firewall rules | Allow only required health check, proxy, PSC, and backend traffic. |
| Cloud NAT, if needed | Private egress for managed services without public IPs. |

## Northbound Entry

```text
Internet clients
  -> regional external Application Load Balancer
  -> Cloud Armor
  -> PSC backend / NEG
  -> Apigee service attachment
  -> Apigee runtime
```

Provisioning dependencies:

1. Apigee organization and instance in non-VPC-peering mode.
2. Apigee northbound service attachment details.
3. Regional external Application Load Balancer.
4. PSC NEG/backend pointed at the Apigee service attachment.
5. TLS certificate and public DNS record.
6. Cloud Armor policy attached to the LB backend service.

## Southbound Backend Publication

```text
Apigee runtime
  -> endpoint attachment in Apigee
  -> customer service attachment
  -> producer load balancer
  -> Cloud Run or private backend
```

Provisioning dependencies:

1. Producer load balancer for the backend service.
2. PSC service attachment that targets the producer load balancer.
3. Service attachment connection preference restricted to the Apigee project where practical.
4. Apigee endpoint attachment created against the service attachment.
5. Apigee API proxy TargetEndpoint using the endpoint attachment host IP or private DNS name.

## Cloud Run Backend

Cloud Run is the baseline application runtime. The service must be configured so it cannot bypass Apigee:

- Ingress restricted to internal/load-balancing path.
- Dedicated runtime service account.
- Secrets pulled from Secret Manager.
- Structured logging enabled.
- Optional Serverless VPC Access only if direct private egress is required.

## Hub and On-Premises

The existing Hub VPC is an external dependency for this project. The API spoke must integrate through approved hub routing, not unauthorized transitive peerings.

Required data to confirm:

- Hub VPC CIDRs.
- VPN advertised routes.
- On-premises prefixes.
- Firewall rules between Hub and API spoke.
- Whether Network Connectivity Center, Shared VPC, VPN, or peering already exists for the spoke-to-hub path.

## Terraform Implementation Order

1. Enable required APIs.
2. Create/verify Terraform state bucket.
3. Create deployment/runtime service accounts and IAM.
4. Create API VPC and subnets.
5. Provision Cloud Armor policy and load-balancing skeleton.
6. Provision Apigee non-VPC-peering organization/instance.
7. Wire northbound PSC to Apigee.
8. Deploy Cloud Run backend.
9. Publish southbound PSC service attachment.
10. Create Apigee endpoint attachment and API proxy target.
11. Validate external, private backend, and on-premises flows.

Steps 6 through 10 may need sequencing between Terraform and Apigee APIs depending on provider support and available organization permissions.

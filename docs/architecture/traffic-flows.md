+++
title = "Traffic Flows — Apigee Challenge"
domain = "architecture"
tier = 2
topics = ["traffic", "data-plane", "apigee", "psc", "cloud-run", "flows", "hop-by-hop"]
parent = "docs/architecture/architecture.md"
children = []
related = [
    "docs/architecture/architecture.md",
    "docs/networking/network-architecture.md",
    "docs/networking/addressing-plan.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/architecture.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Related**: [`network-architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/network-architecture.md) | [`addressing-plan.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/addressing-plan.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Hop-by-hop description of the target data-plane traffic flows for the Apigee Challenge platform.
- Questions Answered: How does a request travel from the internet to the Cloud Run backend? What is the path through Apigee and PSC? What are the VPC boundary crossings?
- When to Retrieve: Debugging connectivity, writing firewall rules, building sequence diagrams, or tracing a specific flow.
- When NOT to Retrieve: When high-level component overview is needed (use architecture.md) or CIDR ranges (use addressing-plan.md).
-->

# Traffic Flows

This document describes the target data-plane flows for the Rocket Code API platform design Challenge. The authoritative challenge brief is `Challenge/challenge.md`.


## 1. External Client to Apigee Runtime

```text
External client
  -> public DNS for api.example.com
  -> regional external Application Load Balancer in us-south1
  -> Cloud Armor security policy
  -> Private Service Connect NEG / backend
  -> Apigee service attachment
  -> provider-managed Apigee runtime
```

| Hop | Boundary | Protocol | Control |
|---|---|---|---|
| Client to LB | Internet to customer edge | HTTPS 443 | TLS certificate, DNS, Cloud Armor |
| LB to PSC backend | Customer edge to private producer attachment | Google-managed LB data plane | PSC NEG/backend service |
| PSC to Apigee | Customer project to provider-managed Apigee VPC | Private Service Connect | Apigee service attachment |

Return traffic follows the established load-balancer and PSC connection back to the client. Backends are not involved in this flow until Apigee routes a validated API request.


## 2. Apigee to Cloud Run Backend

```text
Apigee runtime
  -> Apigee endpoint attachment
  -> customer PSC service attachment
  -> internal backend load-balancing layer
  -> serverless NEG
  -> Cloud Run service
```

| Hop | Boundary | Protocol | Control |
|---|---|---|---|
| Apigee to endpoint attachment | Provider-managed runtime to provider-side PSC object | HTTP or HTTPS target URL configured in Apigee | Apigee proxy policy and TargetEndpoint |
| Endpoint attachment to service attachment | Provider to customer-controlled project | Private Service Connect | Service attachment accept list |
| Service attachment to backend LB | Customer API/backend VPC | HTTP(S) | Internal/regional backend service |
| Backend LB to Cloud Run | Customer project service boundary | HTTPS | Serverless NEG and Cloud Run ingress restriction |

The transition from Apigee back into the customer-controlled network occurs at the customer PSC service attachment. Cloud Run must not allow direct public bypass through the default `run.app` endpoint.


## 3. Apigee to On-Premises Backend

```text
Apigee runtime
  -> Apigee endpoint attachment
  -> customer PSC service attachment
  -> private backend/proxy tier in API VPC
  -> Hub VPC route
  -> HA Cloud VPN
  -> on-premises Java application
  -> relational database
```

| Hop | Boundary | Protocol | Control |
|---|---|---|---|
| Apigee to customer PSC | Provider to customer network | Private Service Connect | Endpoint attachment and service attachment |
| API VPC to Hub VPC | Spoke to central network | Private RFC1918 routing | Existing hub-and-spoke route controls |
| Hub to on-premises | GCP to data center | IPSec/IKEv2 | HA VPN, firewall, route advertisements |
| Java app to database | On-premises application/data boundary | Database protocol | Existing on-prem controls |

The design does not add unauthorized transitive VPC peering. If the existing Hub cannot route API VPC prefixes to on-premises, the route gap must be fixed in the sanctioned hub connectivity layer, not by peering Apigee to more networks.


## 4. Backend Response Path

Cloud Run and on-premises backends return responses over the same established private path:

```text
Backend
  -> internal load-balancing / routing path
  -> customer PSC service attachment
  -> Apigee endpoint attachment
  -> Apigee runtime
  -> northbound PSC and load balancer
  -> external client
```

Firewall rules and route tables must allow the response path. For on-premises traffic, on-premises routing must know the GCP prefixes that represent the customer-side backend/proxy layer.


## 5. Administrative and Deployment Access

```text
Engineer / CI identity
  -> Terraform
  -> Google Cloud APIs
  -> GCP resources and Apigee control plane
```

Administrative access is control-plane traffic, not API data-plane traffic. It must use a dedicated deployment service account, least-privilege IAM, audit logging, and no checked-in service-account keys.


## 6. Monitoring and Logging Flow

```text
Load Balancer / Cloud Armor logs
  -> Cloud Logging / Monitoring
Apigee analytics
  -> Apigee telemetry
Cloud Run logs and traces
  -> Cloud Logging / Trace
VPN metrics
  -> Cloud Monitoring
```

The high-latency on-premises scenario is investigated by correlating latency across the edge, Apigee, PSC, backend, VPN, Java application, and database. The load balancer does not itself fix database or on-premises latency.

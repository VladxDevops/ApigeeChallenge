+++
title = "Security Model — Apigee Challenge"
domain = "security"
tier = 2
topics = ["security", "zero-trust", "iam", "vpc-sc", "firewall", "apigee", "gcp", "mTLS"]
parent = "README.md"
children = []
related = [
    "docs/architecture/architecture.md",
    "docs/networking/network-architecture.md",
    "docs/decisions/architecture-decisions.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Architecture**: [`architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/architecture.md)
> **Network**: [`network-architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/networking/network-architecture.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Security model for the Apigee Challenge platform, covering IAM, VPC-SC, mTLS, Apigee API security, and Zero Trust principles.
- Questions Answered: What IAM roles are needed? How is mTLS enforced? What are the firewall deny-all defaults? How does VPC Service Control apply?
- When to Retrieve: Security review, IAM planning, writing Terraform IAM resources, or evaluating compliance with Zero Trust requirements.
- When NOT to Retrieve: When only network topology is needed (use network-architecture.md) or architecture overview (use architecture.md).
-->

# Security Model

## 1. Security Objectives

- Expose only the controlled API edge to the Internet.
- Keep Apigee as a provider-managed trust boundary outside the customer VPC.
- Prevent direct public access to Cloud Run and on-premises backends.
- Use least-privilege IAM for deployment and runtime identities.
- Store secrets in Secret Manager or managed certificate services, never in Git.
- Preserve enough audit and telemetry data for the oral defense.


## 2. Authentication

| Flow | Mechanism | Enforcement Point |
|---|---|---|
| External clients to APIs | OAuth 2.0/OIDC with JWT validation; API keys only for lower-risk partner identification | Apigee policies |
| Service-to-service calls to Cloud Run | IAM-authenticated invocation where supported; signed token or mTLS if the producer load-balancing path requires it | Cloud Run / backend service |
| Operator access | Google IAM, MFA, audit logging | Google Cloud control plane |
| Hub/on-premises network path | VPN peer authentication and firewall policy | Cloud VPN / on-prem gateway |

The baseline is OAuth 2.0/OIDC for third-party and channel clients because the platform exposes APIs to internal and external consumers.

## 3. Authorization

Apigee enforces API-level authorization:

- Validate issuer, audience, expiry, and signature for JWTs.
- Map scopes or claims to API products and proxy flows.
- Apply quota and spike-arrest policies per application/client.
- Reject unauthorized requests before routing to private backends.

Backends enforce service-level authorization:

- Cloud Run uses a dedicated runtime service account.
- Only approved caller identities or load-balancing paths can invoke the backend.
- On-premises targets allow only approved GCP/VPN source ranges and application credentials.

## 4. TLS and Encryption

| Segment | Encryption |
|---|---|
| Client to external LB | HTTPS, TLS 1.2+ with Google-managed or customer-managed certificate. |
| LB to Apigee over PSC | Private Google network path; use HTTPS target settings where applicable. |
| Apigee to backend over southbound PSC | Prefer HTTPS to target service; validate certificate when using DNS name. |
| Hub to on-premises | IPSec through HA Cloud VPN. |
| Secrets at rest | Secret Manager / Google-managed encryption; CMEK optional if required. |

External TLS terminates at the regional external Application Load Balancer. Apigee remains the API policy enforcement point after traffic reaches the managed runtime.

## 5. Secrets

Use Secret Manager or Certificate Manager for:

- OAuth/OIDC client secrets where needed.
- Backend credentials that cannot yet use token-based auth.
- VPN pre-shared keys if Cloud VPN is provisioned by Terraform.
- Customer-managed TLS private keys, if Google-managed certs are not used.

Do not commit passwords, tokens, private keys, service-account key JSON, `.tfvars` containing secrets, or Terraform state files.

## 6. IAM

Use separate identities:

| Identity | Purpose | Notes |
|---|---|---|
| Terraform deployer service account | Provision GCP/Apigee resources | Bootstrap with needed roles, then reduce where practical. |
| Cloud Run runtime service account | Run application backend | No broad project roles. |
| Apigee administration identity | Manage org, environments, endpoint attachments, proxies | Limit to Apigee admins/operators. |
| CI/CD identity | Build and deploy application artifacts | Separate from runtime identity. |

Avoid primitive roles such as Owner, Editor, and Viewer for day-2 operation.

## 7. Network Security Controls

- Cloud Armor policy on the public entry point.
- No direct public backend endpoints.
- PSC service attachment accept lists restricted to approved projects where possible.
- Firewall rules scoped to required health check, proxy, PSC, and backend ranges.
- Cloud Run ingress restricted to internal/load-balancing access.
- Route advertisements reviewed for both request and response paths.

## 8. Logging and Audit

Enable and review:

- Cloud Audit Logs for IAM, Terraform-managed resources, Apigee administration, and Secret Manager.
- Load Balancer request logs.
- Cloud Armor security logs.
- Apigee analytics and API monitoring.
- Cloud Run request logs.
- VPN tunnel metrics and logs.

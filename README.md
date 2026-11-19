+++
title = "Public README — Rocket Code Apigee Challenge"
domain = "entry-point"
tier = 1
topics = ["apigee", "gcp", "terraform", "ansible", "cloud-architecture", "resume"]
parent = "README.md"
children = [
  "docs/architecture/architecture.md",
  "docs/decisions/architecture-decisions.md",
  "docs/networking/addressing-plan.md",
  "docs/security/security-model.md",
  "docs/assumptions/assumptions-risks-tradeoffs.md"
]
related = [
  "AGENTS.md",
  "AI_MANIFEST.toml",
  "Challenge/challenge.md",
  "platform/GCP/terraform/README.md",
  "platform/GCP/ansible/README.md"
]
updated_by = "GitHub Copilot"
version = "1.2"
+++

# Rocket Code — GCP & Apigee Cloud Platform Implementation

**Status:** Implemented and end-to-end verified in DEV

**Primary technologies:** Google Cloud Platform, Apigee X, Terraform, Ansible, Cloud Run, PSC, Cloud Armor, HA VPN

**Repository role:** Cloud Architecture portfolio, Infrastructure-as-Code implementation, deployment automation, and technical-exercise defense record

This repository is a reproducible implementation of the Rocket Code Cloud Engineer / Cloud Architect technical exercise. It demonstrates how to expose APIs through a provider-managed Apigee runtime while preserving private connectivity, least-privilege identity boundaries, and customer-controlled infrastructure.

The project is suitable as both an architecture review artifact and a resume/CV portfolio item. It shows infrastructure design, Terraform implementation, network security, service integration, Ansible automation, live GCP validation, and technical documentation.

## Verified Outcome

The DEV implementation was successfully provisioned and validated:

- Proxy `hello-world-proxy` revision `12` deployed to the `dev` environment.
- Apigee deployment is `READY`.
- Southbound endpoint attachment is `ACTIVE/ACCEPTED`.
- Northbound smoke test reached the proxy through `34.0.141.222`.
- End-to-end request returned `HTTP 200` and the healthy Cloud Run response.
- Cloud Run logs confirmed receipt of the verified request.
- Required Terraform outputs resolve successfully and drive Ansible runtime values.

This evidence demonstrates the complete northbound and southbound path:

```text
Public client
  -> Regional External Application Load Balancer
  -> Cloud Armor
  -> Northbound Private Service Connect
  -> Apigee X runtime
  -> Southbound endpoint attachment
  -> Producer Private Service Connect service attachment
  -> Internal HTTPS load balancer
  -> Private Cloud Run backend
```

## Executive Summary

The implementation treats Apigee as a provider-managed trust boundary rather than as resources inside the customer VPC. Organization-owned IP addresses are not assigned to the provider runtime, and the provider-managed runtime is not modeled as an ordinary customer subnet.

- A dedicated API spoke VPC provides customer-controlled networking.
- Regional proxy-only and PSC NAT subnets support GCP load balancing and Private Service Connect.
- Northbound traffic enters through a regional external load balancer protected by Cloud Armor.
- Apigee receives northbound traffic through a PSC endpoint.
- Southbound traffic from Apigee reaches Cloud Run through PSC and an internal HTTPS load balancer.
- Simulated hub and on-premises networks provide the hybrid-connectivity boundary.
- Cloud Run uses private ingress and a dedicated runtime service account.
- Terraform owns infrastructure; Ansible owns guarded proxy operations and post-deployment verification.

## Technical Skills Demonstrated

- Google Cloud network architecture and route design
- Apigee X organization, environment, instance, envgroup, and endpoint attachment configuration
- Northbound and southbound Private Service Connect
- Terraform modules, variables, remote state, targeted recovery, plans, and live refreshes
- Cloud Run private ingress and serverless networking
- Regional external and internal Application Load Balancers
- Cloud Armor and least-privilege firewall/IAM design
- TLS certificates and service identity management
- Ansible inventory, roles, playbooks, guarded deployments, API validation, and secret handling
- Infrastructure evidence collection and operational troubleshooting
- Progressive-disclosure architecture documentation

## Architecture Snapshot

- **Architecture:** [docs/architecture/architecture.md](docs/architecture/architecture.md)
- **Traffic flows:** [docs/architecture/traffic-flows.md](docs/architecture/traffic-flows.md)
- **Architecture decisions:** [docs/decisions/architecture-decisions.md](docs/decisions/architecture-decisions.md)
- **Addressing plan:** [docs/networking/addressing-plan.md](docs/networking/addressing-plan.md)
- **Network design:** [docs/networking/network-architecture.md](docs/networking/network-architecture.md)
- **Security model:** [docs/security/security-model.md](docs/security/security-model.md)
- **Risks and assumptions:** [docs/assumptions/assumptions-risks-tradeoffs.md](docs/assumptions/assumptions-risks-tradeoffs.md)
- **Deployment runbook:** [docs/operations/deployment-and-validation.md](docs/operations/deployment-and-validation.md)

## Repository Structure

- `platform/GCP/terraform/` — Terraform root module and reusable GCP modules.
- `platform/GCP/ansible/` — guarded Apigee proxy deployment and verification automation.
- `APPS/APIgee/` — canonical proxy bundle and sample backend assets.
- `APPS/AppsPlatform/hello-backend/` — Cloud Run backend source.
- `docs/` — public architecture, networking, security, operations, and decision records.
- `tests/` — Terraform and networking validation.
- `scripts/` — repository validation helpers.
- `changelog.md` — chronological implementation record.
- `transcripts.md` — concise AI-agent and implementation session index.

## Terraform Implementation

Terraform is the source of truth for infrastructure and cloud-owned identities.

```bash
cd platform/GCP/terraform
terraform fmt -recursive
terraform init
terraform validate
terraform plan -var-file=./environments/DEV/dev.tfvars
```

Do not run `terraform apply` in a shared or production environment without authorization and plan review.

Terraform provisions and refreshes:

- API spoke VPC, subnets, peering, routing, and firewall policy
- Regional external and internal Application Load Balancers
- Cloud Armor security policy
- Northbound and southbound PSC components
- Apigee organization, runtime instance, environment, envgroup, and endpoint attachment
- Private Cloud Run backend and Artifact Registry
- Dedicated runtime and deployment identities
- Hybrid hub/on-premises simulation
- Secret Manager and observability resources

The Terraform entry point is [platform/GCP/terraform/README.md](platform/GCP/terraform/README.md).

## Ansible Automation

Ansible is the operational automation layer for Apigee proxy delivery and end-to-end verification. It does not replace Terraform and does not create or modify Cloud Run, VPC, IAM, load-balancer, PSC, or Apigee infrastructure resources.

**How it works:**

1. `resolve_terraform_values.yml` reads authoritative values from Terraform state.
2. The deploy guard requires an explicit environment confirmation.
3. Preflight checks validate required executables and variables.
4. Bundle validation rejects malformed XML or policy configuration mismatches.
5. The old ZIP is removed, the bundle is rebuilt, and a new Apigee revision is imported.
6. The exact imported revision is deployed with the Terraform-managed runtime service account.
7. Ansible waits for `READY` and repeats the deployment verification for that revision.
8. Verification checks the endpoint attachment, deployment state, instance route, northbound HTTP path, and Cloud Run logs.

### Terraform values consumed by Ansible

| Terraform output | Ansible purpose |
|---|---|
| `compute_project_id` | Project and Apigee organization identifier |
| `apigee_service_account_email` | Exact proxy runtime service account |
| `apigee_endpoint_attachment_host` | Southbound target host and bundle target URL |
| `northbound_ip` | Northbound smoke-test destination |

### Run verification

Always run from the Ansible directory:

```bash
cd platform/GCP/ansible
ansible-playbook playbooks/verify-path.yml --syntax-check
ansible-playbook playbooks/verify-path.yml
```

The verification playbook is read-only from the infrastructure perspective. It validates live Apigee and Cloud Run path state without deploying a new proxy revision.

### Deploy a proxy

```bash
cd platform/GCP/ansible
APIGEE_DEPLOY_ENV=dev ansible-playbook playbooks/deploy-proxy.yml -e deploy_wait_retries=60
```

The deployment playbook:

- Refuses to run in Ansible check mode.
- Requires `APIGEE_DEPLOY_ENV` to match the inventory environment.
- Stops unresolved or placeholder Terraform values before deployment.
- Requires the exact proxy target `https://<Terraform endpoint host>/hello`.
- Enables TLS validation bypass only in `dev`.
- Imports one new revision, deploys exactly that revision, and verifies it is `READY`.
- Never prints or saves the gcloud access token.

Detailed usage is in [platform/GCP/ansible/README.md](platform/GCP/ansible/README.md).

## Direct HTTPS Smoke Test

The resolved northbound address can be tested directly:

```bash
curl -vk --resolve api.example.com:443:34.0.141.222 \
  -H 'Host: api.example.com' \
  https://api.example.com/hello
```

The DEV environment may use an ephemeral certificate and a local `--resolve` override. It does not establish a DNS production cutover.

## Security Boundaries

- Backends are not exposed directly to the public Internet.
- Cloud Run uses private ingress and runtime IAM.
- Provider-managed Apigee remains outside the organization-owned VPC.
- PSC is used for northbound and southbound private attachment paths.
- Deployment and runtime identities are separated.
- WAF, firewall, TLS, Secret Manager, logging, and audit controls are documented in the security model.
- Terraform state and credentials are never committed.

## Validation Status

- Terraform formatting and validation: passed.
- DEV Terraform implementation: applied and refreshed.
- Required Terraform outputs: available.
- Apigee endpoint attachment: `ACTIVE/ACCEPTED`.
- Proxy deployment: revision `12` is `READY`.
- Northbound HTTP smoke test: `200`.
- Cloud Run log correlation: confirmed.
- Final Terraform plan reconciliation: 0 additions and 0 destructions, with only a state-label reconciliation outstanding.

## Cautions

- DEV Secret Manager values are placeholders and must be replaced with managed development secrets.
- The live DNS zone and public certificate lifecycle are not implied by the local smoke test.
- Target/private CIDR assumptions must be reconciled against real organizational inventory before production use.
- Any shared or production Terraform apply requires explicit authorization and review.
- The repository contains no service-account key or credential JSON.

## Portfolio and Resume Summary

This project demonstrates hands-on capability across:

- **Cloud Engineering:** GCP VPC, load balancing, serverless compute, hybrid networking, private service connectivity, and observability.
- **API Platform Engineering:** Apigee runtime setup, proxy delivery, service attachments, environment routing, and identity integration.
- **Infrastructure as Code:** Terraform module design, environment variables, state management, dependency recovery, and validation.
- **Automation:** Ansible roles and playbooks for guarded deployment and live path verification.
- **Security:** IAM least privilege, private ingress, WAF controls, TLS, secret separation, and trust-boundary documentation.
- **Technical Communication:** Architecture records, ADRs, traffic flows, runbooks, changelogs, assumptions, and oral-defense material.

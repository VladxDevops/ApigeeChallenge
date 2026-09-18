# Rocket Code — Cloud API Platform Architecture


## 1. Purpose

This document defines the target architecture for the Rocket Code Cloud Engineer / DevOps technical exercise.

The project is being implemented as a **new project**. This document establishes the architectural direction that the Terraform code must implement and validate.

The architecture is intentionally practical and limited to the minimum components necessary to satisfy the exercise, demonstrate sound cloud/networking/security decisions, and be deployable and explainable within a few days.

The authoritative exercise requirements are stored verbatim in:

`challenge.md`

When this document and `challenge.md` conflict, `challenge.md` has priority. Official Google Cloud / Apigee documentation is authoritative for product behavior and implementation capabilities.

---


## 2. Priority Order

The project is optimized according to the following priorities:


### Priority 1 — Deliverability in a few days

The solution must be practical, focused, and small enough to implement, validate, document, and present within the available time.

Avoid:

- Unnecessary multi-region complexity. keep things single region like the Load balancer. 
- Unnecessary Kubernetes/GKE infrastructure. We`ll be working with Cloud Run. 
- Unnecessary custom networking components
- Unnecessary services that do not help satisfy the exercise
- Over-engineering for hypothetical production requirements


### Priority 2 — Security

Security receives deliberate attention without sacrificing delivery speed.

The design must protect the API edge, prevent direct backend exposure, use least-privilege IAM, protect secrets, use TLS, and make trust boundaries explicit.


### Priority 3 — Architectural correctness and requirement coverage

Every important component must directly support a requirement, a documented assumption, or a necessary technical dependency.

The final design must correctly solve:

- northbound traffic into the managed runtime
- southbound traffic toward private backends
- private connectivity
- transition into the internal network
- non-transitive connectivity
- non-overlapping addressing
- secure API exposure
- hybrid/on-premises reachability


### Priority 4 — Reproducibility and implementation quality

Terraform is the infrastructure source of truth.

The final environment must be reproducible and changes must not depend on undocumented manual console configuration.


### Priority 5 — Validation and observability

The project must provide enough monitoring, logging, tracing, and functional validation to demonstrate that the architecture actually works and to investigate latency and connectivity failures.


### Priority 6 — Documentation and oral-defense readiness

Documentation should explain the selected design and trade-offs clearly without becoming a large documentation project.

The final architecture must be explainable without AI assistance.

---


## 3. Company Requirements

See `challenge.md` for the verbatim Rocket Code requirements.

The supplied diagram establishes the following context:

- external clients
- a new API project / spoke that we design
- an external entry point protected by a WAF
- an API VPC
- a provider-managed tenant outside our VPC
- a provider-managed API runtime whose IP addressing is not controlled by us
- a new application platform/project using containers and managed services. We`ll use Cloud Run for this. 
- an existing central Hub VPC
- on-premises core business systems
- a Java application server
- a relational database


The exercise specifically asks the design to determine:

- how traffic enters the managed runtime
- how traffic returns toward backends
- which private connectivity artifacts are used
- which special subnets are required
- where traffic transitions to the internal network

The exercise prohibits:

- direct Internet exposure of backends
- assigning organizational IPs to the managed runtime
- assuming the provider routes arbitrary private customer CIDRs
- solving transitively with additional VPC peerings
- overlapping existing network ranges
- manual configuration instead of reproducible IaC. We`ll be using Terraform for deployment. 

---


## 4. Architectural Principles

1. **Private by default.**
2. **No direct public backend exposure.**
3. **Provider-managed Apigee remains outside the customer VPC boundary.**
4. **Private Service Connect is the primary connectivity mechanism between customer-controlled services and Apigee.**
5. **Do not use transitive VPC peering.**
6. **Terraform is the source of truth.**
7. **Use managed services where they materially reduce operational work.**
8. **Keep one primary region for the exercise.**
9. **Assumptions are explicit and testable.**
10. **Every major component must have a documented reason to exist.**

---

## 5. Selected Architecture

### 5.1 API Management Networking Model

**Selected:** Apigee with **Non-VPC-peering networking**.

This is the baseline architecture decision.

In the current Google Cloud documentation, the non-VPC-peering model uses Private Service Connect for:

- northbound traffic from clients to Apigee
- southbound traffic from Apigee to target services in customer-controlled projects

It does not require dedicated customer IP ranges to be supplied for the Apigee organization during provisioning.

Reference:

- https://docs.cloud.google.com/apigee/docs/api-platform/get-started/networking-options
- https://docs.cloud.google.com/apigee/docs/api-platform/architecture/overview

This model aligns with the exercise because the managed runtime remains outside the customer VPC and we do not need to introduce VPC peering or assign customer address space to the runtime.

---

## 6. Regional Strategy

### Selected primary region

`us-south1`

The exercise allows the candidate to define the region. `us-south1` is the current working region because the required managed services and the intended regional networking pattern are available there.

The design is **regional**, not tied to one zone.

Use a zone such as `us-south1-a` only when a specific zonal resource actually requires one.

Do not force regional managed services into an artificial single-zone architecture.

---

## 7. High-Level Architecture

```text
                         EXTERNAL CLIENTS
                                |
                                | HTTPS
                                v
                  +-------------------------------+
                  | Regional External Application |
                  | Load Balancer                 |
                  | Region: us-south1             |
                  +---------------+---------------+
                                  |
                         Cloud Armor / WAF
                                  |
                                  v
                         NORTHBOUND PSC
                                  |
                                  v
                  +-------------------------------+
                  | Provider-Managed Apigee       |
                  | Non-VPC-Peering Architecture  |
                  | Region: us-south1             |
                  +---------------+---------------+
                                  |
                         API policies / routing
                                  |
                                  v
                         SOUTHBOUND PSC
                                  |
                                  v
                  +-------------------------------+
                  | Private Producer / Backend    |
                  | Connectivity Layer            |
                  +---------------+---------------+
                                  |
                    +-------------+-------------+
                    |                           |
                    v                           v
              +-----------+              +-------------+
              | Cloud Run |              | Private /   |
              | services  |              | Hybrid      |
              +-----------+              | backends    |
                                           +------+------+ 
                                                  |
                                                  v
                                           +-------------+
                                           | Hub VPC     |
                                           | Central     |
                                           +------+------+ 
                                                  |
                                               VPN /     
                                             hybrid link
                                                  |
                                                  v
                                           +-------------+
                                           | On-Premises  |
                                           | Java + DB    |
                                           +-------------+
```

This is the conceptual architecture. The exact Terraform resource topology must be validated against current Google Cloud / Apigee capabilities before implementation is considered complete.

---

## 8. Northbound Traffic

Northbound means traffic from API consumers toward Apigee.

### Selected flow

```text
External Client
    |
    | HTTPS
    v
Regional External Application Load Balancer
    |
    | Cloud Armor policy
    v
Private Service Connect
    |
    v
Apigee Managed Runtime
```

The regional external Application Load Balancer provides the controlled Internet-facing entry point.

Cloud Armor provides the edge/WAF policy associated with the load-balancing layer.

Private Service Connect (PSC) connects the customer-controlled load-balancing path to the Apigee service attachment.

Google currently documents non-VPC-peering Apigee with PSC northbound routing through an external or regional external Application Load Balancer. The classic global external HTTP(S) load balancer is not the target for this architecture.

References:

- https://docs.cloud.google.com/apigee/docs/api-platform/system-administration/northbound-networking-psc
- https://docs.cloud.google.com/apigee/docs/api-platform/get-started/install-cli-non-peered-eval

---


## 9. Southbound Traffic

Southbound means traffic from Apigee toward API target services.

### Selected conceptual flow

```text
Apigee Managed Runtime
    |
    v
PSC Endpoint Attachment
    |
    v
PSC Service Attachment
    |
    v
Customer-controlled private producer / backend layer
    |
    +------> Cloud Run
    |
    +------> private cloud backend
    |
    +------> hybrid backend path
```

For southbound PSC, the customer-controlled target side publishes the service through a service attachment, while Apigee uses an endpoint attachment in the Apigee VPC.

The exact producer-side load-balancing pattern must be validated before implementation.

References:

- https://docs.cloud.google.com/apigee/docs/api-platform/architecture/southbound-networking-patterns-endpoints
- https://docs.cloud.google.com/apigee/docs/api-platform/troubleshoot/playbooks/network-configuration/connectivity-with-sb-psc-targets

---


## 10. Cloud Run Backend

Cloud Run is the selected application runtime for the cloud backend portion of the exercise.

Reasons:

- container-based
- fully managed
- less operational overhead than GKE
- sufficient for the exercise
- supports Serverless NEGs and load-balancing patterns
- keeps the implementation small

Cloud Run must not become a public bypass around the API management architecture.

Where Cloud Run is exposed through an external load balancer, use the appropriate restricted ingress setting so direct Internet requests to the default `run.app` endpoint are not allowed.

Reference:

- https://docs.cloud.google.com/run/docs/securing/ingress
- https://docs.cloud.google.com/load-balancing/docs/https/setting-up-reg-ext-https-serverless

---


## 11. Hybrid Connectivity

The supplied diagram identifies an existing central Hub VPC and on-premises business systems.

### Exercise assumption

Use **Cloud VPN** as the baseline hybrid connectivity mechanism.

This is a practical exercise-level assumption designed to demonstrate private reachability without introducing the additional complexity of Dedicated Interconnect.

For a production design with materially higher throughput, deterministic performance, or stronger availability requirements, Interconnect would be evaluated separately.

Conceptual path:

```text
Private Backend Layer
        |
        v
     Hub VPC
        |
        v
   Cloud VPN
        |
        v
   On-Premises
        |
    +---+---+
    |       |
    v       v
 Java App  RDBMS
```

The design must document how routes are propagated between the customer network, Hub VPC, VPN, and on-premises ranges.

---


## 12. Security Architecture

Security is the second project priority after delivery speed.

### 12.1 Perimeter

- Regional External Application Load Balancer
- Cloud Armor
- TLS
- controlled public entry point

### 12.2 API security

Apigee is the API management and policy enforcement boundary.

The implementation should use an authentication/authorization mechanism appropriate to the assumed client population and document the assumption.

Possible mechanisms to evaluate include:

- OAuth 2.0 / OIDC
- JWT validation
- API keys where justified
- mTLS where justified by the threat model

Do not add authentication mechanisms only for appearance.

### 12.3 Backend security

- backend services must not be directly exposed to the Internet
- Cloud Run ingress must be restricted appropriately
- private connectivity is preferred
- service identity and IAM must follow least privilege
- secrets must use Secret Manager

### 12.4 IAM

Use dedicated identities for:

- Terraform / deployment
- runtime services
- supporting automation

Avoid broad primitive roles where more specific predefined roles are practical.

### 12.5 Secrets

Secrets are stored in Google Secret Manager.

Do not commit:

- passwords
- tokens
- API secrets
- private keys
- service-account private keys

### 12.6 TLS

Document:

- where external TLS terminates
- which connections remain encrypted after termination
- certificate ownership
- certificate lifecycle
- whether mTLS is actually required

---

## 13. Addressing Strategy

All customer-controlled CIDRs must be non-overlapping.

Before finalizing new ranges, inventory:

- existing API VPC ranges
- existing Hub VPC ranges
- assumed on-premises ranges
- PSC-specific ranges
- any service-specific reserved ranges

The exercise does not provide exact existing CIDRs, so any unknown existing ranges must be explicitly declared as assumptions.

The current proposed addressing plan is maintained in `docs/networking/addressing-plan.md` and uses the following exercise-level ranges:

| Network / Subnet | CIDR | Size | Purpose | Region | Owner | Notes |
|---|---|---:|---|---|---|---|
| API VPC supernet | `10.80.0.0/16` | /16 | API spoke | us-south1 | Customer | Proposed, must validate against real IPAM. |
| API private subnet | `10.80.0.0/24` | 256 IPs | Private backend/proxy resources | us-south1 | Customer | Regular subnet. |
| Regional proxy-only subnet | `10.80.1.0/24` | 256 IPs | Regional Envoy load balancer proxies | us-south1 | Customer | `REGIONAL_MANAGED_PROXY`. |
| PSC NAT subnet | `10.80.2.0/24` | 256 IPs | PSC producer NAT | us-south1 | Customer | `PRIVATE_SERVICE_CONNECT`. |
| Hub VPC | `10.20.0.0/16` | /16 | Existing central network | Existing | Customer | Assumption. |
| On-premises | `10.0.0.0/12` | /12 | Existing internal network | On-prem | Organization | Assumption. |

Do not invent unknown production ranges and represent them as factual.

---

## 14. Latency and Observability

The source diagram explicitly states that the on-premises environment experiences high latency during peak hours.

The architecture must not claim that a load balancer automatically eliminates this latency.

Instead, observability must identify where latency occurs.

Use, as practical:

- Cloud Monitoring
- Cloud Logging
- Cloud Trace
- Apigee telemetry / analytics
- Load Balancer logging
- Cloud Armor logging
- Cloud Run telemetry
- relevant network telemetry

The investigation path should be:

```text
Client
  -> Load Balancer
  -> PSC
  -> Apigee
  -> PSC
  -> Backend
  -> Hub
  -> VPN
  -> On-Prem Java Application
  -> Database
```

The project should use telemetry to distinguish:

- edge latency
- API gateway processing time
- backend application latency
- hybrid-network latency
- database latency

The practical objective is not to build a complete enterprise observability platform. It is to collect enough evidence to validate the architecture and explain the high-latency scenario intelligently.

---

## 15. Trust Boundaries

The architecture has at least these major trust boundaries:

1. Internet / external clients → customer-controlled API edge.
2. Customer-controlled API edge → provider-managed Apigee environment.
3. Provider-managed Apigee → customer-controlled backend producer.
4. Customer cloud networks → central Hub VPC.
5. GCP Hub → on-premises network.
6. Application services → data services.
7. Human/operator identities → cloud control plane.

The provider-managed Apigee environment must remain visually and conceptually outside the customer's VPC.

---

## 16. Network Boundaries

The final diagram must clearly distinguish:

### Customer-controlled

- API project/spoke
- customer VPC
- external load balancer
- Cloud Armor policy
- PSC customer-side resources
- Cloud Run project/service
- Hub VPC
- hybrid connectivity resources

### Provider-controlled

- Apigee managed tenant
- Apigee managed runtime
- provider-side service attachment / infrastructure as documented

### External / outside GCP

- Internet clients
- on-premises network

Do not draw Apigee as if it were simply another subnet inside the customer VPC.

---

## 17. Important Architectural Questions to Validate

These are implementation validation items, not assumptions to hide.

### Northbound

- Exact PSC NEG / service attachment configuration required by Apigee.
- Regional external Application Load Balancer resource topology.
- Certificate requirements.
- DNS requirements.
- Cloud Armor integration.
- Health-check / failover behavior.

### Southbound

- Exact endpoint attachment configuration.
- Exact producer load balancer required for the target service.
- Cloud Run Serverless NEG compatibility in the selected topology.
- Required producer subnet and PSC subnet.
- Global access requirements if producer and consumer regions differ.
- Target port and protocol requirements.
- Return traffic behavior.

### Hybrid

- Route propagation.
- Cloud VPN topology.
- On-prem destination prefixes.
- Return routes.
- Firewall rules.

### Terraform

- Current Google provider support for each selected resource.
- Required APIs.
- Resource dependency ordering.
- Whether any provisioning action remains CLI-only or has a documented Terraform equivalent.

Any unresolved technical dependency must remain marked `UNVERIFIED` until validated.

---

## 18. Design Scope Control

The following are intentionally out of scope unless `challenge.md` or an implementation dependency makes them necessary:

- multi-region production architecture
- GKE/Kubernetes
- service mesh
- enterprise-scale API developer portal
- full CI/CD platform redesign
- complex enterprise WAN redesign
- advanced disaster recovery program
- large-scale data platform
- unnecessary microservice decomposition
- custom proxies or VM-based network bridges when PSC provides the required connectivity

The goal is a convincing technical exercise, not a complete enterprise platform.

---

## 19. Expected Implementation Sequence

1. Inspect current repository and Terraform.
2. Compare current implementation with `challenge.md`.
3. Validate Apigee Non-VPC-peering + PSC capabilities.
4. Finalize northbound topology.
5. Finalize southbound topology.
6. Finalize Cloud Run backend pattern.
7. Finalize hybrid connectivity assumption.
8. Finalize CIDRs and special subnet requirements.
9. Implement Terraform.
10. Validate deployment and connectivity.
11. Add security controls.
12. Add practical observability.
13. Produce E1–E5 supporting artifacts.
14. Perform an oral-defense review.

Do not spend significant time polishing diagrams or documentation before the networking path is technically validated.

---

## 20. Success Criteria

The architecture is considered successful when we can demonstrate, with evidence:

- an external client can reach the API through the intended secure entry point
- traffic reaches Apigee through the selected PSC architecture
- Apigee can reach the selected private backend through southbound PSC
- the backend is not directly exposed to the Internet
- the Cloud Run service cannot be used as a public bypass
- private backend connectivity is reproducible through Terraform
- the intended path toward on-premises is private and documented
- CIDRs are non-overlapping under stated assumptions
- IAM and secrets are appropriately controlled
- logs/metrics/traces provide useful validation evidence
- the entire architecture can be explained clearly during the oral defense

---

## 21. Final Architecture Statement

The target solution is a **single-region, practical GCP API platform** using:

- **Apigee without VPC peering**
- **Private Service Connect for northbound and southbound connectivity**
- **Regional External Application Load Balancer for external API entry**
- **Cloud Armor for WAF/perimeter protection**
- **Cloud Run for the cloud application runtime**
- **Hub VPC for central internal connectivity**
- **Cloud VPN as the exercise-level hybrid connectivity assumption**
- **Cloud Monitoring, Logging and Trace for practical observability**
- **Secret Manager and least-privilege IAM for security**
- **Terraform as the reproducible infrastructure source of truth**

The architecture deliberately avoids VPC peering between the API project and the provider-managed Apigee environment and avoids exposing the backend tier directly to the Internet.

The exact PSC resource topology and Terraform implementation must be validated against current official documentation before being treated as final.

---

## 22. Primary References

Google Cloud / Apigee official documentation:

- Apigee networking options: https://docs.cloud.google.com/apigee/docs/api-platform/get-started/networking-options
- Apigee architecture overview: https://docs.cloud.google.com/apigee/docs/api-platform/architecture/overview
- Apigee northbound PSC: https://docs.cloud.google.com/apigee/docs/api-platform/system-administration/northbound-networking-psc
- Apigee southbound PSC: https://docs.cloud.google.com/apigee/docs/api-platform/architecture/southbound-networking-patterns-endpoints
- Apigee non-peering provisioning: https://docs.cloud.google.com/apigee/docs/api-platform/get-started/install-cli-non-peered-eval
- Cloud Run ingress: https://docs.cloud.google.com/run/docs/securing/ingress
- Regional external Application Load Balancer with Cloud Run: https://docs.cloud.google.com/load-balancing/docs/https/setting-up-reg-ext-https-serverless
- Cloud Armor: https://docs.cloud.google.com/armor/docs/integrating-cloud-armor

The technical exercise requirements themselves remain in `challenge.md` and take precedence over this document where there is any conflict.

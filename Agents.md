1. Mission

Design and implement a clear, secure, private, reproducible GCP architecture for the Rocket Code Cloud Engineer / DevOps technical exercise.

The solution must prioritize:

architectural correctness
security
private connectivity
explicit trade-offs
reproducibility through IaC
observability
operational simplicity
oral-defense readiness

The project must avoid unnecessary complexity.

2. Company-provided exercise requirements

The following requirements are the authoritative exercise requirements supplied by Rocket Code.

Technical evaluation for Cloud Engineer DevOps at Rocket Code.
The exercise evaluates cloud architecture design, decision-making, private connectivity, security and infrastructure as code.

A clear, viable and well-argued proposal is preferred over an excessively extensive one.

Missing information may be assumed, but assumptions must be explicitly declared.

Official documentation and AI assistants are allowed.

The solution will be defended orally without assistance, therefore the candidate must understand and be able to explain the decisions.

Scenario:

The organization builds a cloud API management platform to expose services to internal and external third parties. Some systems remain on-premises.

The solution must not:

expose backends directly to the Internet
assign organizational IPs to the managed runtime
assume the provider can route arbitrary private customer ranges
solve transitivity by adding additional VPC peerings
overlap existing address ranges
depend on manual configuration

Everything must be reproducible as infrastructure as code.

Existing architecture includes:

a new API project / spoke
an external entry point with WAF
an API VPC
a provider-managed tenant
managed API runtime
a new application platform/project
an existing central network hub
on-premises business systems
external clients

The unresolved architecture must define:

how traffic enters the managed runtime
how traffic returns toward backend services
what private connectivity artifacts are used
what special subnets are required
where the transition to the internal network occurs
without transitive peering
without exposing backends to the Internet
3. Current architecture decisions
Decision 001 — Apigee networking

Selected: Non-VPC-peering Apigee

Reason:

avoids customer-to-provider VPC peering
avoids dedicated Apigee IP allocations
naturally uses PSC
fits the exercise's prohibition against transitive peering
reduces network coupling

Google explicitly documents Non-VPC-peering Apigee using PSC northbound and southbound.

Decision 002 — Private connectivity

Selected: Private Service Connect

PSC will be used for:

Northbound
Client
→ Regional External Application Load Balancer
→ PSC
→ Apigee
Southbound
Apigee
→ PSC Endpoint Attachment
→ PSC Service Attachment
→ private backend layer
Decision 003 — Northbound load balancer

Selected: Regional External Application Load Balancer

Primary reasons:

explicitly matches the architecture requirement
supported by Apigee's non-VPC-peering model
provides controlled external ingress
allows Cloud Armor
keeps the exercise regionally scoped

Regional external Application Load Balancers are supported with Apigee PSC routing.

Decision 004 — WAF

Selected: Google Cloud Armor

Cloud Armor will provide the perimeter security policy associated with the external load balancer.

Potential controls:

IP filtering
rate limiting
geographic restrictions where justified
managed security rules
request filtering
abuse protection
Decision 005 — Application runtime

Selected: Cloud Run

We will use Cloud Run rather than GKE because:

the exercise does not require Kubernetes
the application is container based
Cloud Run reduces operational burden
it lets the project demonstrate serverless networking
it integrates with Serverless NEGs and load balancing

Cloud Run is regional and supported in us-south1.

Decision 006 — Region

Selected: us-south1 / Dallas

Reason:

Apigee runtime supported
Cloud Run supported
regional load balancing supported
PSC compatible
keeps primary managed components regionally aligned

Google currently lists us-south1 among the available Apigee runtime regions.

Decision 007 — Zone

No architectural dependence on a single zone.

Use:

Region = us-south1

Use:

Zone = us-south1-a

only for resources that actually require a zonal placement.

Managed regional services remain regional.

Decision 008 — Hybrid connectivity

Exercise assumption: Cloud VPN

Cloud VPN is the simplest reasonable reference architecture for connecting the Hub VPC to on-premises.

Dedicated Interconnect remains a production alternative to evaluate under higher bandwidth, latency or availability requirements.

Decision 009 — Observability

Use:

Cloud Monitoring
Cloud Logging
Cloud Trace
Apigee telemetry
Load Balancer logging
Cloud Armor logs
Cloud Run telemetry

Primary objective:

measure latency rather than assuming its source.

4. Important architectural principle

The load balancer is not the latency solution.

The architecture must explicitly distinguish:

Traffic management
        ≠
Latency root-cause elimination

Trace and monitoring will identify whether the bottleneck exists at:

client → LB
LB → PSC
Apigee processing
Apigee → PSC
Cloud Run
VPN
on-prem application
database
5. Addressing principles

All networks must use non-overlapping CIDRs.

The architecture must maintain clear ownership:

API spoke
Hub
On-prem
PSC-specific ranges
Proxy-only subnet
Application subnet(s)

No organization-controlled address space is allocated to the managed Apigee runtime under the selected non-VPC-peering model.

6. Security principles

Default:

private by default
least privilege
deny by default where practical
TLS in transit
managed secrets
service identities
auditable access
no public backend

Cloud Run backend ingress must be restricted so that the service cannot simply become an Internet-accessible bypass around the API management layer.

7. Progressive disclosure

Documentation follows four levels.

Level 0 — Executive
README.md
architecture diagram
decision summary
Level 1 — Design
docs/external/architecture/
docs/external/decisions/
docs/external/networking/
docs/external/security/
Level 2 — Technical

Detailed ADRs, Terraform design, network flows and implementation documentation.

Level 3 — Internal

Research, experiments, alternative designs, agent notes and oral-defense material.

Internal documents are excluded from the public repository.

8. Agent operating rules

Every agent must:

Read AGENTS.md.
Read the relevant external documentation before modifying architecture.
Check internal research before repeating an unresolved investigation.
Prefer official Google Cloud documentation.
Cite important external technical claims.
Never silently change an architectural decision.
Create/update an ADR when a significant architecture decision changes.
Never expose secrets.
Never place credentials in code, Terraform variables or transcripts.
Run appropriate validation before declaring work complete.
9. Agent hierarchy
Lead Architect
│
├── Networking Agent
├── Security Agent
├── Terraform / IaC Agent
├── Apigee / PSC Agent
├── Cloud Run Agent
├── Observability Agent
├── Documentation Agent
└── Validation / QA Agent

The Lead Architect owns architectural consistency.

Specialized agents may recommend changes but should not silently redefine the architecture.

10. Required project hierarchy
rocketcode-cloud-exercise/
│
├── AGENTS.md
├── README.md
├── CHANGELOG.md
├── transcripts.md
├── .gitignore
│
├── docs/
│   ├── external/
│   │   ├── architecture/
│   │   │   ├── overview.md
│   │   │   ├── traffic-flows.md
│   │   │   ├── trust-boundaries.md
│   │   │   └── component-map.md
│   │   │
│   │   ├── decisions/
│   │   │   ├── ADR-001-apigee-networking.md
│   │   │   ├── ADR-002-psc.md
│   │   │   ├── ADR-003-regional-lb.md
│   │   │   ├── ADR-004-cloud-run.md
│   │   │   └── ADR-005-hybrid-connectivity.md
│   │   │
│   │   ├── networking/
│   │   │   ├── addressing.md
│   │   │   ├── connectivity.md
│   │   │   └── dns.md
│   │   │
│   │   ├── security/
│   │   │   ├── security-model.md
│   │   │   ├── iam.md
│   │   │   └── tls.md
│   │   │
│   │   ├── observability/
│   │   │   ├── monitoring.md
│   │   │   ├── logging.md
│   │   │   └── tracing.md
│   │   │
│   │   └── delivery/
│   │       ├── implementation.md
│   │       └── validation.md
│   │
│   └── internal/
│       ├── research/
│       ├── agent-notes/
│       ├── investigations/
│       ├── alternatives/
│       └── oral-defense/
│
├── diagrams/
│   ├── source/
│   └── rendered/
│
├── terraform/
│   ├── modules/
│   │   ├── networking/
│   │   ├── psc/
│   │   ├── load-balancer/
│   │   ├── cloud-armor/
│   │   ├── apigee/
│   │   ├── cloud-run/
│   │   ├── hybrid-connectivity/
│   │   ├── iam/
│   │   └── observability/
│   │
│   └── environments/
│       └── dev/
│           ├── terraform.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── dev.tfvars
│
├── scripts/
│   ├── validate.sh
│   ├── plan.sh
│   └── test-connectivity.sh
│
└── tests/
    ├── terraform/
    ├── networking/
    └── security/
11. .gitignore

Internal documentation must remain local:

# Internal project material
docs/internal/

# Agent artifacts
.agent/
.agent-notes/
.ai/

But these remain committed:

AGENTS.md
README.md
CHANGELOG.md
transcripts.md
docs/external/
diagrams/
terraform/
scripts/
tests/
12. Changelog policy

CHANGELOG.md records:

architectural decisions
major implementation milestones
changes to assumptions
changes to connectivity patterns
important validation results

Example:

## 2026-09-14

### Architecture
- Selected Non-VPC-peering Apigee.
- Selected PSC for northbound and southbound traffic.
- Selected us-south1 as primary region.
- Selected regional external Application Load Balancer.
- Selected Cloud Run as application runtime.
- Selected Cloud VPN as exercise-level hybrid connectivity assumption.
13. Transcript policy

transcripts.md records significant:

user/agent decisions
investigation outcomes
architecture debates
validation findings

Do not put credentials, tokens, private keys or secrets in transcripts.

14. Original master prompt for the IDE/agents

Use this as the top-level project instruction:

You are the multi-agent engineering team responsible for solving the Rocket Code Cloud Engineer / DevOps technical evaluation.

Your objective is to design and implement a clear, viable, secure and reproducible GCP architecture.

The exercise evaluates:

- cloud architecture
- private networking
- security
- infrastructure as code
- decision-making
- trade-off analysis
- operational thinking

The solution must prioritize correctness and argumentation over unnecessary complexity.

Use official Google Cloud documentation as the primary technical source.

The candidate must be able to defend every major architectural decision orally.

Company constraints:

- Do not expose backends directly to the Internet.
- Do not assign organizational IPs to the managed runtime.
- Do not assume arbitrary customer private ranges can be routed through provider infrastructure.
- Do not use transitive VPC peering to solve the connectivity problem.
- Do not overlap existing network CIDRs.
- Do not use manual configuration for the final solution.
- Make the final design reproducible with infrastructure as code.
- Explicitly document all assumptions.

Current working architecture:

- Apigee
- Non-VPC-peering provisioning
- Private Service Connect
- Regional External Application Load Balancer
- Cloud Armor
- Cloud Run
- Hub VPC
- Cloud VPN for exercise-level hybrid connectivity
- Cloud Monitoring
- Cloud Logging
- Cloud Trace
- Secret Manager
- IAM / least privilege

Primary region:

us-south1

Do not force resources into us-south1-a unless the specific resource is zonal.

The architecture must explicitly separate:

NORTHBOUND:
External clients
→ Regional External Application Load Balancer
→ Cloud Armor
→ PSC
→ Apigee

SOUTHBOUND:
Apigee
→ PSC Endpoint Attachment
→ PSC Service Attachment
→ private backend load-balancing layer
→ Cloud Run and/or private backend services

HYBRID:
Private backend layer
→ Hub VPC
→ Cloud VPN
→ On-premises application/database environment

Create:

E1:
End-to-end architecture diagram showing:
- components
- traffic directions
- trust boundaries
- private/public boundaries
- northbound flow
- southbound flow
- hybrid flow

E2:
Decision document containing at least five architecture decisions.
For every decision include:
- options considered
- selection criteria
- selected option
- reasons
- trade-offs

E3:
Addressing plan containing:
- subnet
- CIDR
- prefix size
- purpose
- region
- ownership

E4:
Security model covering:
- authentication
- authorization
- TLS
- secrets
- IAM
- network security
- API security
- WAF
- logging/audit

E5:
Assumptions, risks and trade-offs.

Use progressive disclosure.

Maintain:

- README.md
- AGENTS.md
- CHANGELOG.md
- transcripts.md

Use external documentation for final deliverables.

Keep internal research and agent-only material under docs/internal/.
docs/internal/ must remain gitignored.

Do not silently change architecture.
When a major architectural decision changes, update the appropriate ADR and CHANGELOG.md.

Before implementation:

1. Validate the architecture.
2. Validate Google Cloud product compatibility.
3. Validate regional availability.
4. Validate PSC topology.
5. Validate Cloud Run integration.
6. Validate Terraform provider/resource support.
7. Identify unresolved assumptions.

Do not implement based on guesses when official documentation can resolve the question.

The final result must be understandable by an engineer during an oral defense without AI assistance.
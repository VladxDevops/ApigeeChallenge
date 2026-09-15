1. Current priorities — highest to lowest
Priority 0 — Respect the exercise's hard constraints

This is the highest priority because a technically clever solution is still wrong if it violates one of the explicit constraints.

We must guarantee:

No backend is directly exposed to the Internet.
We do not assign organization-owned IP ranges to the managed Apigee runtime.
We do not assume arbitrary private customer routes can be injected into the provider-managed Apigee network.
We do not use transitive VPC peering to solve connectivity.
No CIDR overlap with existing networks.
Everything reproducible through IaC.
The design must have a defensible security model.
Every important assumption must be explicitly documented.
2. Primary architecture decision — Non-VPC-peering Apigee + PSC

This is now our baseline architecture.

Google explicitly documents two Apigee networking choices:

VPC peering
Non-VPC peering

The non-VPC-peering model uses Private Service Connect for both northbound and southbound traffic and does not require us to allocate the Apigee instance's dedicated /22 and /28 ranges.

That is almost tailor-made for the exercise constraints.

Why we prefer it

It avoids introducing:

VPC peering between the API spoke and Apigee
dedicated Apigee network ranges
transitive-routing arguments
unnecessary coupling between our network and the provider's network

And it lets us demonstrate exactly the technologies Rocket Code mentioned:

Apigee + PSC + regional Load Balancer + private hybrid connectivity.

3. Northbound connectivity

The external request path becomes:

External Client
      |
      | HTTPS
      v
Regional External Application Load Balancer
      |
      +--> Cloud Armor / WAF policy
      |
      v
Private Service Connect
      |
      v
Apigee Managed Runtime

Google's Apigee documentation explicitly supports regional external load balancing with PSC for the non-VPC-peering architecture.

The regional external Application Load Balancer is therefore not decorative. It is a real architectural component of the northbound path.

4. Southbound/private backend connectivity

Our second major priority is proving that Apigee can privately reach the services.

Conceptually:

Apigee
  |
  | PSC
  v
PSC Endpoint Attachment
  |
  v
PSC Service Attachment
  |
  v
Private/Internal Load Balancer
  |
  +----> Cloud Run
  |
  +----> private application/backend
  |
  +----> hybrid/on-prem path

For Cloud Run specifically, Google documents the pattern of using a load balancer with a Serverless NEG and publishing the service through PSC.

This is very important because it means the backend can remain private instead of becoming an Internet-facing service.

5. Hybrid/on-prem connectivity

The existing Hub VPC is the bridge toward on-prem.

For this exercise, we should deliberately choose the simplest viable hybrid technology rather than pretending we're designing a Fortune-500 production WAN.

My current assumption:

API / Backend VPC
       |
       | private connectivity
       v
   Hub VPC
       |
       | Cloud VPN
       v
   On-Prem Network
       |
       +--> Java application
       |
       +--> Relational DB

Cloud VPN is the reasonable exercise assumption because the prompt gives us no bandwidth, SLA, regulatory, or latency requirement that would force Dedicated Interconnect.

We document:

"Cloud VPN is selected as the reference hybrid-connectivity mechanism for the exercise because it minimizes infrastructure complexity while satisfying private connectivity requirements. Dedicated Interconnect would be evaluated for a production environment with higher throughput, deterministic latency, or stronger availability requirements."

That is a very defensible interview answer.

6. Security

Security comes immediately after connectivity.

We need to demonstrate security at several layers:

Internet
   |
Cloud Armor
   |
TLS
   |
Regional External LB
   |
PSC
   |
Apigee
   |
Apigee policies
   |
PSC
   |
Private backend

We need to cover:

TLS termination
TLS between components where appropriate
Apigee authentication
authorization
API keys / OAuth where appropriate
rate limiting / quotas
Cloud Armor
IAM
Secret Manager
service accounts
least privilege
private-only backend ingress
no public backend exposure
logging and auditability

Cloud Armor integrates with Application Load Balancing, including regional external Application Load Balancers.

7. Addressing plan

Only after the architecture is stable should we finalize CIDRs.

We need a small, clean addressing plan such as:

API Spoke VPC
├── proxy-only subnet
├── PSC / connectivity subnet(s)
├── application subnet(s), if required
└── reserved future space

Hub VPC
└── existing corporate ranges

On-Prem
└── existing corporate ranges

The major rule:

No overlap.

We don't need enormous ranges merely to make the architecture look impressive.

8. Observability and latency

Your Cloud Trace idea is absolutely worth keeping.

We should implement:

Cloud Monitoring
Cloud Logging
Cloud Trace
Apigee analytics/metrics
Cloud Armor logs
Load Balancer logs
Cloud Run telemetry
Hybrid connectivity metrics

And specifically investigate the latency chain:

Client
  ↓
Regional LB
  ↓
PSC
  ↓
Apigee
  ↓
PSC
  ↓
Backend
  ↓
Hub
  ↓
VPN
  ↓
On-Prem Java
  ↓
Database
Important interview point

We should not claim that the Load Balancer solves the high latency problem.

The LB gives us:

controlled ingress
traffic distribution
regional routing
health-aware behavior
scalable entry

But it cannot magically make a slow on-prem database fast.

Our answer should be:

"The load balancer improves ingress architecture and traffic management, while Cloud Trace and Cloud Monitoring allow us to identify where latency actually occurs. Root-cause mitigation may involve regional placement, backend scaling, connection management, caching where appropriate, or improvement of hybrid connectivity."

That's a much stronger architectural answer.

9. Terraform / IaC

Everything important must ultimately be reproducible.

Target:

Terraform
   |
   +--> APIs
   +--> VPC
   +--> subnets
   +--> firewall rules
   +--> PSC
   +--> load balancer
   +--> Cloud Armor
   +--> Cloud Run
   +--> IAM
   +--> Secret Manager
   +--> monitoring
   +--> logging
   +--> DNS

We shouldn't manually configure the final architecture and then try to retrofit Terraform later.

10. Deliverables and oral defense

Only after all the above is solid do we polish:

E1 diagram
E2 decision document
E3 addressing plan
E4 security model
E5 assumptions / risks / trade-offs
oral-defense preparation

The architecture must be understandable without the slide deck doing the thinking for us.

Region decision: us-south1 vs us-central1
us-south1 is completely legitimate

Current Google documentation lists:

Apigee runtime → us-south1 ✅
Cloud Run → us-south1 ✅
Regional external Application Load Balancer → regional deployments are supported ✅
PSC → regional architecture ✅

Google's Apigee location documentation currently lists Dallas / us-south1 as an available Apigee runtime region.

Cloud Run also officially supports us-south1.

Regional external Application Load Balancers support Cloud Run backends and operate within a configured region.

So:

No, choosing us-south1 is not trying too hard. It is actually a reasonable architectural choice.

And from a presentation perspective, I like it better because we can explicitly say:

Selected region: us-south1 (Dallas)
Chosen because Apigee and Cloud Run are both available there, the architecture can remain regionally aligned, and it avoids artificially defaulting everything to us-central1.

What about us-south1-a?

Here I'd make an important distinction.

Don't say:

"The architecture uses zone us-south1-a."

because most of our important services are regional managed services, not zonal resources.

Cloud Run is regional and Google manages redundancy across the zones within the region.

Apigee's runtime is likewise managed regionally and Google states the infrastructure is redundantly available across zones in that region.

The regional Application Load Balancer is also a regional construct.

So our architectural definition should be:

REGION = us-south1

and only resources that genuinely require a zone would use something such as:

ZONE = us-south1-a

That is more architecturally correct than forcing every resource into us-south1-a.

My recommendation
Region: us-south1
Zone: us-south1-a only where a zonal resource requires it

That looks intentional rather than lazy.

Updated architecture baseline

This is what I currently want the project agents to treat as the working architecture:

                         INTERNET
                            |
                            v
                   +----------------+
                   | External Client|
                   +----------------+
                            |
                          HTTPS
                            |
                            v
               +---------------------------+
               | Regional External         |
               | Application Load Balancer |
               |       us-south1            |
               +-------------+-------------+
                             |
                     Cloud Armor / WAF
                             |
                             v
                    Private Service
                      Connect PSC
                             |
                             v
                +-------------------------+
                | APIGEE MANAGED RUNTIME  |
                |   Non-VPC-Peering       |
                |       us-south1          |
                +------------+------------+
                             |
                       API policies
                             |
                             v
                    Private Service
                      Connect PSC
                             |
                             v
                    PSC Endpoint /
                    Service Attachment
                             |
                             v
                +-------------------------+
                | Private Backend Layer   |
                | Internal LB / NEG       |
                +------------+------------+
                             |
                +------------+-------------+
                |                          |
                v                          v
          +-------------+          +---------------+
          | Cloud Run   |          | Hybrid Path   |
          | private     |          |               |
          +-------------+          +-------+-------+
                                           |
                                         Hub VPC
                                           |
                                       Cloud VPN
                                           |
                                           v
                                      ON-PREMISES
                                           |
                                  +--------+--------+
                                  |                 |
                                  v                 v
                           Java Application       RDBMS

The exact southbound LB/PSC implementation will be one of the things we validate carefully in Terraform/design, rather than assuming every possible PSC pattern works interchangeably. Google's current PSC documentation supports publishing Cloud Run-backed services through a load balancer and PSC.

Updated version of the outputs from the original prompt

Below is the project baseline I would now feed to the agents.

AGENTS.md — Rocket Code Technical Exercise
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
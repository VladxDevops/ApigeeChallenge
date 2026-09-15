# Architecture — API Platform with Private Connectivity

## 1. Executive Summary

This document describes the end-to-end GCP architecture for a managed API platform that exposes services to external and internal clients while maintaining secure, private connectivity to on-premises backends.

**Key design characteristics:**
- Managed API runtime (Apigee) with Provider-managed isolation
- Private Service Connect (PSC) for inbound and outbound connectivity
- Spoke VPC for API platform with private backends
- Hub VPC for hybrid routing and on-premises connectivity
- Cloud VPN for secure on-premises integration
- Cloud Armor + Application Load Balancer for external protection
- End-to-end encryption and least-privilege IAM

---

## 2. Architecture Overview

### 2.1 High-Level Traffic Flow

```
Internet Client
    ↓ HTTPS
Cloud Armor / External LB (us-central1)
    ↓ PSC Consumer
Apigee Managed Runtime (Provider-controlled)
    ↓ PSC Producer (Private Service Connect)
Internal Service Attachment → Shared VPC / Spoke VPC
    ↓ Private routing
Backend Layer (Cloud Run, other services)
    ↓ (Response through same path)
On-Premises Systems (via Hub VPC + Cloud VPN)
```

### 2.2 Network Topology

The architecture follows a **hub-and-spoke model with provider-managed runtime isolation**:

```
┌─────────────────────────────────────────────────────────────────┐
│                        EXTERNAL INTERNET                        │
│                                                                 │
│  External Client (Browser, Mobile, Third-party API Consumer)    │
└──────────────────────────────┬──────────────────────────────────┘
                               │ HTTPS
                               ↓
                  ┌────────────────────────────┐
                  │  Cloud Armor + Cloud LB    │
                  │  (Global Anycast)          │
                  │  us-central1               │
                  └─────────────┬──────────────┘
                                │ PSC Consumer
                                ↓
            ┌───────────────────────────────────────────┐
            │  APIGEE MANAGED RUNTIME (Provider VPC)    │
            │  - Non-peered, provider-controlled        │
            │  - Executes policies, routes requests     │
            │  - Cross-regional managed service         │
            └──────────────┬────────────────────────────┘
                           │ PSC Producer/Service Attachment
                           ↓
        ┌──────────────────────────────────────────────────┐
        │        SPOKE VPC — API Platform (10.80.0.0/16)   │
        │                                                  │
        │  ┌─────────────────────────────────────────────┐ │
        │  │  PSC Endpoint / Subnet (10.80.1.0/28)       │ │
        │  │  - Private IP for inbound/outbound traffic  │ │
        │  └────────────┬────────────────────────────────┘ │
        │               │                                  │
        │         Private routing (VPC)                    │
        │               │                                  │
        │  ┌────────────┴───────────────────────────────┐  │
        │  │  Backend Regional Subnet (10.80.2.0/24)    │  │
        │  │  - Cloud Run services                      │  │
        │  │  - Network Endpoint Groups (NEG)           │  │
        │  │  - Internal LB                             │  │
        │  └────────────────────────────────────────────┘  │
        │                                                  │
        └───────────────┬──────────────────────────────────┘
                        │ VPC Peering / Transit routing
                        ↓
        ┌──────────────────────────────────────────────────┐
        │        HUB VPC — Shared Services (10.20.0.0/16)  │
        │                                                  │
        │  ┌─────────────────────────────────────────────┐ │
        │  │  Cloud VPN Gateway                          │ │
        │  │  - Hybrid connectivity                      │ │
        │  │  - On-premises routing                      │ │
        │  └────────────┬────────────────────────────────┘ │
        │               │                                  │
        └───────────────┼──────────────────────────────────┘
                        │ IPSec Tunnel
                        ↓
        ┌──────────────────────────────────────────────────┐
        │        ON-PREMISES NETWORK                       │
        │  - Business systems (Java applications, DBs)     │
        │  - Existing infrastructure                       │
        └──────────────────────────────────────────────────┘
```

---


## 3. Detailed Component Description

### 3.1 External Ingress Layer

**Component:** Google Cloud Armor + External Application Load Balancer

**Location:** Global (us-central1 backend)

**Purpose:**
- Protect the API runtime from DDoS and common web attacks
- Provide a single, globally reachable HTTPS endpoint
- Enforce security policies before traffic reaches Apigee
- Handle SSL/TLS termination for external clients

**Configuration:**
- HTTPS listener on port 443
- HTTP/2 support
- Cloud Armor security policies (WAF rules)
- Managed certificates or customer-owned certificates
- Health checks to backend PSC endpoint

**Security Properties:**
- Filters malicious traffic at the edge
- No direct exposure of backend services
- Encrypted transport for all external traffic

---


### 3.2 Apigee Managed Runtime

**Provider:** Google Cloud (Apigee)

**Network Model:** Provider-managed, non-peered environment

**Purpose:**
- Execute API policies (authentication, rate limiting, transformation, etc.)
- Provide single point of API management and governance
- Isolate customer traffic from other tenants
- Manage API versioning and deployment

**Key Properties:**
- **Boundary:** Provider controls the runtime instance; customer cannot directly access internal subnets
- **Connectivity:** Ingress via PSC consumer (from LB), egress via PSC producer (to backends)
- **Cross-Region:** Multi-region managed service (automatic failover, no customer configuration required)
- **Addressing:** Provider-assigned; customer has no control over Apigee's internal IPs
- **Policies:** Customer configures policies (condition, flow rules, targets) via deployment or UI

**Traffic Semantics:**
- Inbound: External LB → PSC Consumer → Apigee Runtime
  - Source: Client IP (via LB)
  - Destination: Apigee service endpoint
  - Protocol: HTTP/1.1 or HTTP/2
  
- Outbound: Apigee Runtime → PSC Producer → Private backends
  - Source: Apigee-assigned IP (provider range, not customer range)
  - Destination: Backend IP inside spoke VPC
  - Protocol: HTTP/HTTPS or custom protocols

---


### 3.3 Private Service Connect (PSC) — Connectivity Mechanism

**Service:** Google Cloud Private Service Connect

**Purpose:** Bridge provider-managed runtime to customer-controlled networks without exposing provider infrastructure or assigning organization IPs to the runtime.

**Two-Sided Connection:**

**Inbound PSC (Apigee Consumer):**
- External LB acts as PSC consumer
- Connects to Apigee managed service via private, GCP-internal network path
- No internet routing, no VPN, no peering required
- Automatic DNS resolution to provider endpoint

**Outbound PSC (Apigee Producer → Backend):**
- Apigee acts as PSC producer when reaching private backends
- Customer creates Service Attachment in spoke VPC
- Apigee connects via private IP to the backend network
- Backends appear as "local" to Apigee (no public IP required)

**Addressing:**
- PSC inbound: 10.80.1.0/28 (2-4 private IPs reserved for PSC endpoint)
- PSC outbound: Apigee → Service Attachment
  - Source: Apigee-assigned provider range (e.g., 10.90.0.0/16 — **non-overlapping** with customer networks)
  - Destination: Backend subnet 10.80.2.0/24

---


### 3.4 Spoke VPC — API Platform

**CIDR:** 10.80.0.0/16

**Region:** us-central1 (primary), us-east1 (secondary for HA)

**Purpose:** Dedicated VPC for the new API platform, isolating it from existing organizational networks.

**Subnets:**

| Subnet Name | CIDR | Size | Purpose | Region |
|---|---|---:|---|---|
| psc-endpoint-subnet | 10.80.1.0/28 | 16 IPs | PSC endpoint (inbound/outbound) | us-central1 |
| backend-primary | 10.80.2.0/24 | 256 IPs | Cloud Run, app services | us-central1 |
| backend-secondary | 10.80.3.0/24 | 256 IPs | Cloud Run, app services | us-east1 |
| management | 10.80.100.0/24 | 256 IPs | Operator access, logging | us-central1 |

**Routing:**
- Local routes: Internal VPC routing via primary/secondary ranges
- Hub VPC route: 10.80.0.0/16 → Hub VPC peering for on-premises traffic
- PSC route: Backend traffic to PSC endpoint (automatic GCP routing)

---


### 3.5 Hub VPC — Shared Services & Hybrid Connectivity

**CIDR:** 10.20.0.0/16

**Purpose:** Central hub for organizational services and on-premises connectivity.

**Subnets:**

| Subnet Name | CIDR | Size | Purpose |
|---|---|---:|---|
| vpn-gateway-subnet | 10.20.1.0/29 | 8 IPs | Cloud VPN gateway interface |
| shared-services | 10.20.2.0/24 | 256 IPs | Centralized services |

**Connectivity:**
- VPC Peering: Spoke VPC ↔ Hub VPC (bidirectional)
- Cloud VPN: Hub VPC ↔ On-Premises (IPSec tunnel)

---


### 3.6 On-Premises Network

**CIDR:** 10.0.0.0/8 (assumed; customer must specify actual range)

**Purpose:** Existing organizational infrastructure (Java applications, databases, business systems).

**Connectivity:**
- Cloud VPN tunnel terminates in hub VPC
- Routes for on-prem services learned via VPN or static routes
- Return traffic automatically routed back through VPN tunnel

---

## 4. Traffic Flows

### 4.1 External Client → API → Cloud Backend

```
1. Internet Client                                (e.g., 203.0.113.5:54321)
   ↓ HTTPS request (api.example.com)
   
2. Cloud Armor + External LB                      (Global Anycast IP, e.g., 34.X.X.X)
   - Evaluate security policies
   - Create PSC connection to Apigee (outbound)
   
3. PSC Inbound Path                               (10.80.1.0/28 → Apigee)
   - Route: 10.80.1.0/28 CONSUME apigee.googleapis.com
   - Source: LB internal IP
   - Destination: Apigee managed service
   
4. Apigee Managed Runtime                         (Provider-controlled, non-VPC)
   - Execute API policies:
     * JWT validation (or API key auth)
     * Rate limiting
     * Request transformation
     * Target assignment
   - Resolve target backend service (from policy)
   
5. PSC Outbound Path                              (Apigee → Service Attachment)
   - Source: Apigee-assigned IP (10.90.0.0/16 example)
   - Destination: 10.80.2.0/24 (backend subnet)
   - Route: Auto-discovered via Service Attachment
   
6. Backend Layer                                  (Cloud Run, NEG)
   - Receive request on private IP
   - Execute business logic
   - Return response
   
7. Response Path (Reverse)
   - Cloud backend → PSC Outbound → Apigee → PSC Inbound → LB → Client
   - All encryption maintained end-to-end

Timeline: ~100–300ms (depending on backend processing)
```

---

### 4.2 API → On-Premises Backend

```
1. Apigee Runtime (after policy execution)        (Provider-controlled)
   - Determine target: internal backend (on-prem)
   - Resolve DNS or static route for on-prem service
   
2. PSC Outbound Path                              (Apigee → Service Attachment)
   - Source: Apigee-assigned IP
   - Destination: Spoke VPC backend (10.80.2.0/24)
   
3. Spoke VPC Internal Routing                     (10.80.0.0/16)
   - Route destined for on-prem (e.g., 10.1.0.0/16)
   - Next hop: Hub VPC peering gateway
   
4. VPC Peering                                    (Spoke ↔ Hub)
   - Spoke routing table: 10.1.0.0/16 → hub-peering-gateway
   - Hub routing table: 10.80.0.0/16 → spoke-peering-gateway
   - Peering exchange: EXPORT_CUSTOM_ROUTES, IMPORT_CUSTOM_ROUTES
   
5. Hub VPC Routing                                (10.20.0.0/16)
   - Route for on-prem (e.g., 10.1.0.0/16)
   - Next hop: Cloud VPN gateway
   
6. Cloud VPN Tunnel                               (IPSec, user-managed VPN)
   - Encryption: Phase 1 (IKEv2), Phase 2 (AES-GCM)
   - Source: 10.80.x.x or 10.20.x.x (from hub subnet)
   - Destination: 10.1.0.0/16 (on-prem)
   
7. On-Premises Network
   - Receive request on private IP
   - Process (access DB, business logic)
   - Return response through reverse path
   
8. Response Path
   - On-prem → VPN tunnel → Hub → Spoke → Apigee → External LB → Client

Timeline: ~200–500ms (VPN latency + business logic)
```

---

### 4.3 Operator Access (Administrative)

```
1. Operator (within Spoke VPC or via Cloud Identity / Admin Console)
   
2. Access Terraform deployments:
   - Service account authentication (JSON key or Workload Identity)
   - Terraform state in Cloud Storage (encrypted, versioned)
   
3. Access Apigee management:
   - Apigee API via service account (OAuth 2.0)
   - Deploy policies, manage traffic targets
   
4. Access backend services:
   - Cloud Run service via internal LB (if needed)
   - Or via Cloud Shell / Identity-Aware Proxy (IAP)
   
5. Logging / Monitoring:
   - Cloud Logging (centralized)
   - Cloud Monitoring (metrics, dashboards)
   - Service account reads logs (least privilege)
```

---

## 5. Security Boundaries

### 5.1 Trust Boundaries

**Boundary 1: Internet ↔ Cloud Armor**
- Untrusted external traffic
- Cloud Armor enforces policies
- Transition: HTTPS encryption

**Boundary 2: Cloud Armor ↔ Apigee**
- Processed external traffic (after WAF)
- PSC private path (GCP network, not internet)
- Transition: Authenticated via PSC (provider handles isolation)

**Boundary 3: Apigee ↔ Customer Networks**
- Apigee (provider-managed) ↔ Spoke VPC (customer-managed)
- PSC Producer / Service Attachment provides isolation
- Apigee uses non-customer IP range (10.90.0.0/16 assumed)
- Transition: Connectivity only through PSC endpoint

**Boundary 4: Spoke VPC ↔ Hub VPC**
- API platform (new) ↔ Shared organizational services
- VPC peering with controlled route export/import
- Transition: Private VPC peering

**Boundary 5: Hub VPC ↔ On-Premises**
- GCP (hub) ↔ On-premises (external VPN endpoint)
- Cloud VPN encryption
- Transition: IPSec tunnel with mutual authentication

---

### 5.2 Network Boundaries

Each network segment is isolated by firewall rules, routing policies, and service connectivity:

- **External** → Filtered by Cloud Armor
- **PSC Inbound** → Encrypted transit, provider-managed
- **Apigee** → Provider boundary (no direct access, not addressable by customer)
- **Spoke VPC** → Private IP only, firewall rules enforce egress/ingress
- **Hub VPC** → Private IP only, VPN-gated for external connectivity
- **On-Prem** → IPSec tunnel, VPN authentication required

---

## 6. Addressing Summary

| Network | CIDR | Size | Provider | Notes |
|---|---|---:|---|---|
| Spoke VPC | 10.80.0.0/16 | 65,536 IPs | Customer | New API platform |
| PSC Endpoint | 10.80.1.0/28 | 16 IPs | Customer (within spoke) | Reserved for PSC |
| Backend Primary | 10.80.2.0/24 | 256 IPs | Customer | us-central1 backends |
| Backend Secondary | 10.80.3.0/24 | 256 IPs | Customer | us-east1 backends |
| Management Subnet | 10.80.100.0/24 | 256 IPs | Customer | Operations/logging |
| Hub VPC | 10.20.0.0/16 | 65,536 IPs | Customer | Existing shared services |
| VPN Gateway Subnet | 10.20.1.0/29 | 8 IPs | Customer | Within hub |
| On-Premises | 10.0.0.0/8 | 16M+ IPs | Customer | Assumed existing |
| Apigee (Assumed) | 10.90.0.0/16 | 65,536 IPs | Provider | Non-overlapping, provider-managed |

**Non-overlap verification:** No CIDR ranges conflict under the stated assumptions. Customer manages 10.0.0.0/8 and 10.20.0.0/16; new speak VPC uses 10.80.0.0/16; Apigee uses separate provider range.

---

## 7. High Availability & Disaster Recovery

### 7.1 API Runtime (Apigee)
- **Managed by provider:** Multi-region, automatic failover across data centers
- **Customer responsibility:** None
- **SLA:** Typically 99.95% (per Apigee SLA)

### 7.2 External LB + Cloud Armor
- **Multi-region:** Global anycast, automatic routing to closest edge location
- **Cross-zone:** Multiple backends across us-central1 and us-east1 (via backends)

### 7.3 Cloud Run Backends
- **Multi-region deployment:** Identical services in us-central1 and us-east1
- **Traffic split:** LB routes to regionally closest instance
- **Failover:** Automatic if region becomes unhealthy

### 7.4 Cloud VPN (On-Premises Connectivity)
- **Redundancy:** Dual tunnels (Active-Active or Active-Passive)
- **On-premises side:** Customer must provide redundant VPN endpoints
- **Failover:** Automatic by BGP or static route fallover

---

## 8. Implementation Notes

**Terraform modules:** 
- `networking/` — VPC, subnets, routing, peering
- `psc/` — Service Attachment, PSC endpoint configuration
- `apigee/` — Apigee organization, environment, API deployments
- `cloud-run/` — Cloud Run services, NEG configuration
- `load-balancer/` — External LB, Cloud Armor policies
- `hybrid-connectivity/` — Cloud VPN, on-premises routing
- `iam/` — Service accounts, IAM bindings
- `observability/` — Logging, monitoring, alerts

**State management:** Remote state in Cloud Storage, encrypted, with versioning enabled.

**Deployment flow:**
1. Deploy networking (VPC, subnets)
2. Deploy PSC infrastructure
3. Deploy backend services (Cloud Run)
4. Deploy Apigee organization + environment
5. Deploy ingress (LB + Cloud Armor)
6. Deploy hybrid connectivity (Cloud VPN)
7. Validate traffic flows end-to-end
8. Enable monitoring and logging

---

## 9. Validation & Testing

See `docs/operations/deployment-and-validation.md` for detailed validation procedures.

# Security Model

## 1. Authentication

### 1.1 External Client → API (Edge)

**Pattern:** OAuth 2.0 / OpenID Connect (RECOMMENDED) or API Keys

**For External Third-Party Clients:**
- **Mechanism:** OAuth 2.0 Authorization Code flow
- **Token issuer:** Company-managed (Google Cloud Identity or custom IdP)
- **Token validation:** Apigee JWT policy validates tokens before routing
- **Endpoint:** `https://api.example.com/oauth2/authorize` and `/oauth2/token`
- **Token lifetime:** 1 hour access token + refresh token
- **Scope:** Fine-grained API scope mapping (e.g., `read:users`, `write:data`)

**For Internal Company Systems:**
- **Mechanism:** Mutual TLS (mTLS) or JWT with service-to-service credentials
- **Certificate:** Issued by company CA or Google Certificate Manager
- **Validation:** Apigee mTLS policy + JWT policy (layered)
- **Credential rotation:** Automatic via secret rotation (see Secrets Management)

**For Mobile/SPA Clients:**
- **Mechanism:** OAuth 2.0 Authorization Code with PKCE
- **Token issuer:** Company-managed or third-party (e.g., Auth0, Okta)
- **Validation:** Apigee validates token signature and claims
- **Refresh:** Automatic refresh via secure HTTP-only cookies or token endpoint

**Implementation:**
```
Cloud Armor → LB → PSC → Apigee (JWT/mTLS policy) → Allow/Deny
  ↓
  If allowed: Route to backend
  If denied: 401 Unauthorized or 403 Forbidden (to client)
```

---

### 1.2 API → Backend Services

**Soft of Trust:** Service-to-service authentication via Workload Identity

**Pattern:**
- Cloud Run services assume a Workload Identity service account
- Service account has IAM binding: `roles/iam.workloadIdentityUser`
- Backends use GCP SDKs (Python/Node/Java) to automatically fetch OAuth 2.0 tokens
- Tokens are short-lived (1 hour default)
- Token audience: Backend service URL

**Implementation:**
```
Cloud Run Pod
  ↓ (via local metadata service)
  Request: GET /computeMetadata/v1/instance/service-accounts/default/identity?audience=https://backend.example.com
  ↓ (Workload Identity intercepts, returns signed token)
  Token: JWT with:
    - Issuer: https://iamcredentials.googleapis.com/google.iam.credentials.v1
    - Subject: projects/PROJECT_ID/locations/global/workloadIdentityPools/...
    - Audience: https://backend.example.com
    - Expiration: 1 hour
    - Signature: ECDSA/RSA
```

**Apigee-to-Backend:**
- Apigee retrieves credentials via similar mechanism (service account assigned to Apigee environment)
- Apigee calls `https://backend.example.com:443` with `Authorization: Bearer <token>`
- Backend validates token signature against Google's public JWKS endpoint

---

### 1.3 On-Premises Backend → API

**Soft of Trust:** Mutual TLS over VPN tunnel

**Pattern:**
- On-premises VPN endpoint presents certificate (client certificate for on-prem side)
- Cloud VPN validates certificate against known CA
- Return traffic authenticated by same certificate
- All traffic encrypted via IPSec IKEv2/AES-GCM

**Implementation:**
```
On-Premises App → Cloud VPN Tunnel (IPSec)
  ↓
  Phase 1: IKE negotiation (mutual authentication via certificates/PSK)
  Phase 2: IPSec tunnel established (AES-256-GCM)
  ↓
  On-prem traffic appears on Hub VPC with source = on-prem IP
  ↓
  Firewall rule: Allow traffic from on-prem CIDR to spoke VPC
  ↓
  Traffic routed to Apigee (if API call) via PSC
```

---

## 2. Authorization

### 2.1 API Level (Apigee Policies)

**Enforcement Point:** Apigee runtime executes policies after JWT validation

**Patterns:**
- **Role-Based Access Control (RBAC):** Token claims include `scope` or `role` (e.g., `"admin"`, `"reader"`)
- **Token introspection:** Apigee calls token endpoint to verify token status (if not embedded)
- **Rate limiting:** Token/user/API key is rate-limited (e.g., 100 requests per minute per user)
- **IP whitelisting:** Optional, for internal APIs only (check CIDR of request source)

**Apigee Policy Example:**
```xml
<!-- JWT Token Validation -->
<VerifyJWT name="VerifyJWT">
  <Source>request.header.authorization</Source>
  <PublicKey>
    <JWKS url="https://company.auth0.com/.well-known/jwks.json" />
  </PublicKey>
  <Claims>
    <Claim name="iss">https://company.auth0.com/</Claim>
  </Claims>
</VerifyJWT>

<!-- Check if user has required scope -->
<RaiseFault name="CheckScope">
  <Condition>NOT (request.headers.authorization.claims.scope contains "read:api")</Condition>
  <FaultResponse>
    <Set>
      <Payload mediaType="application/json">{"error": "Insufficient scope"}</Payload>
      <StatusCode>403</StatusCode>
    </Set>
  </FaultResponse>
</RaiseFault>

<!-- Rate limiting (per-user) -->
<Quota name="RateLimit">
  <Identifier ref="request.headers.authorization.claims.sub" />
  <Allow>100</Allow>
  <Interval>1</Interval>
  <TimeUnit>minute</TimeUnit>
</Quota>
```

---

### 2.2 Backend Service Level (IAM)

**Enforcement:** Cloud Run / Cloud Functions / Custom services

**Permissions:**
- Service account can invoke backend only if granted `roles/run.invoker` (or equivalent)
- Backend receives Workload Identity token, validates issuer and audience
- Request context available via environment variables or headers

**Service Account Bindings:**
```
Service Account: apigee-backend-caller
  ↓ Has role: roles/run.invoker
  ↓ On Cloud Run service: backend-service
  ↓ IAM binding: serviceAccount:...-compute@developer.gserviceaccount.com 
       has roles/run.invoker (actions: run.routes.invoke)
```

**Cloud Run Backend Verification:**
```python
# Pseudocode in Cloud Run service
from flask import request
import google.auth.transport.requests
from google.oauth2 import id_token

token = request.headers.get('Authorization').split(' ')[1]
claims = id_token.verify_oauth2_token(
    token,
    requests.Request(),
    audience=backend_service_url
)
if claims['iss'] == 'https://iamcredentials.googleapis.com/google.iam.credentials.v1':
    # Authorized
    process_request()
else:
    # Unauthorized
    return 403
```

---

### 2.3 Infrastructure/Deployment Level (IAM)

**Terraform Deployment Service Account:**
- `roles/compute.networkAdmin` (VPC, routing, firewall)
- `roles/container.admin` (Cloud Run, GKE if used)
- `roles/apigee.admin` (Apigee organization management)
- `roles/iam.serviceAccountAdmin` (Service account provisioning)
- `roles/secretmanager.admin` (Secret management)
- `roles/storage.admin` (Terraform state bucket)

**Principle:** Least privilege; use custom roles if needed to further restrict permissions.

---

## 3. TLS & Encryption in Transit

### 3.1 External → Cloud Armor → LB → Apigee

**Protocol:** HTTPS (TLS 1.2+)

**Certificate:**
- **Type:** X.509 v3 certificate
- **Issuer:** Google-managed certificate (via Certificate Manager) or customer-provided
- **Common Name (CN):** api.example.com
- **Subject Alternative Name (SAN):** api.example.com, *.api.example.com
- **Key Size:** 2048-bit RSA or 256-bit ECDSA (ECDSA preferred)
- **Validity:** 1 year (auto-renewed)

**Policy:**
- **Minimum TLS version:** TLS 1.2
- **Cipher suites:** Modern ciphers only (ECDHE + AES-GCM)
  - `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`
  - `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`
- **HSTS:** Enabled (Strict-Transport-Security header)

**Termination:**
- External LB terminates TLS for external clients
- LB → Apigee PSC connection uses GCP-internal encryption (no application-level TLS needed, but recommended for defense-in-depth)

---

### 3.2 Apigee → Backend (Cloud Run)

**Protocol:** HTTPS (TLS 1.2+)

**Certificate Validation:**
- Cloud Run services present certificates issued by Google (Google-managed certificate or customer CA)
- Apigee verifies certificate chain before sending requests

**Implementation:**
```
Apigee Policy: Target Endpoint
  <TargetEndpoint name="backend">
    <HTTPTargetConnection>
      <URL>https://backend-internal.example.com:443</URL>
      <SSLInfo>
        <Enabled>true</Enabled>
        <VerifyHostname>true</VerifyHostname>
        <IgnoreValidationErrors>false</IgnoreValidationErrors>
      </SSLInfo>
    </HTTPTargetConnection>
  </TargetEndpoint>
```

---

### 3.3 Cloud VPN (Hub ↔ On-Premises)

**Protocol:** IPSec with IKEv2

**Phase 1 (IKE - Key Exchange):**
- **Encryption:** AES-256-GCM
- **Hashing:** SHA256
- **Diffie-Hellman Group:** Group 20 (FFDH 2048-bit)
- **Lifetime:** 28,800 seconds (8 hours)
- **Authentication:** Pre-shared key (PSK) or certificates

**Phase 2 (IPSec - Data Encryption):**
- **Encryption:** AES-256-GCM
- **Integrity:** SHA256
- **Lifetime:** 3,600 seconds (1 hour)
- **DPD (Dead Peer Detection):** Enabled

**Configuration (Terraform):**
```hcl
resource "google_compute_vpn_tunnel" "tunnel1" {
  name              = "vpn-tunnel-primary"
  local_traffic_selector = ["10.20.0.0/16", "10.80.0.0/16"]
  remote_traffic_selector = ["10.0.0.0/8"]  # on-premises range
  ike_version       = 2
  shared_secret      = var.vpn_shared_secret  # from Secret Manager

  ike_phase1_algorithms = [
    "encryption_aes_256_cbc",
    "integrity_sha256",
    "dh_group20"  # or dh_group_modp2048
  ]
  ike_phase2_algorithms = [
    "encryption_aes_256_gcm",
    "integrity_sha256"
  ]
}
```

---

## 4. Secrets Management

### 4.1 VPN Pre-Shared Key (PSK)

**Storage:** Google Cloud Secret Manager

**Characteristics:**
- **Format:** 32+ character random string (alphanumeric + special chars)
- **Rotation:** Every 90 days (manual trigger or automated pipeline)
- **Access:** Only `terraform-deploy` service account can read
- **Encryption:** Google-managed encryption at rest (CMK optional)

**Creation:**
```bash
echo "$(openssl rand -base64 32)" | gcloud secrets create vpn-psk --data-file=-
```

**Terraform Usage:**
```hcl
data "google_secret_manager_secret_version" "vpn_psk" {
  secret      = google_secret_manager_secret.vpn_psk.id
  version     = "latest"
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  shared_secret = data.google_secret_manager_secret_version.vpn_psk.secret_data
}
```

---

### 4.2 API Authentication Credentials

**For Apigee → Backends (Service Account Keys):**
- **Storage:** Secret Manager (never in code or Terraform state)
- **Format:** JSON (private key + service account email)
- **Rotation:** Every 90 days
- **Access:** Workload Identity preferred (no key export needed)

**Alternative (Recommended):** Use Workload Identity (no keys required, automatic token provisioning)

---

### 4.3 TLS Certificates (Private Keys)

**For customer-provided certificates (not Google-managed):**
- **Storage:** Secret Manager or Google Certificate Manager
- **Format:** PEM-encoded private key
- **Rotation:** Before expiration (typically 1 year)
- **Access:** Only LB configuration service account

---

### 4.4 Database Credentials (If Backends Connect to On-Prem DB)

**Storage:** Secret Manager

**Characteristics:**
- **Format:** Username/password or connection string
- **Rotation:** Quarterly (coordinated with DB team)
- **Access:** Service account running backend service (only)
- **Audit:** All access logged to Cloud Audit Logs

---

## 5. IAM — Detailed Role Assignments

### 5.1 Service Accounts

#### terraform-deploy (Infrastructure Provisioning)
```hcl
# Roles needed:
- roles/compute.networkAdmin         # VPC, subnets, firewall, routes
- roles/compute.loadBalancerAdmin    # LB configuration
- roles/apigee.admin                 # Apigee org, env, API deployment
- roles/container.admin              # Cloud Run, GKE
- roles/iam.serviceAccountAdmin      # Create/manage service accounts
- roles/iam.serviceAccountKeyAdmin   # Manage service account keys (limited)
- roles/secretmanager.admin          # Secret provisioning
- roles/storage.objectAdmin          # Terraform state access
- roles/cloudkms.admin (optional)    # CMK management if using CMEK
```

#### apigee-runtime (Apigee Environment Runtime)
```hcl
# Roles needed:
- roles/run.invoker                  # Invoke Cloud Run backends
- roles/secretmanager.secretAccessor # Read API secrets
```

#### cloud-run-backend (Application Runtime)
```hcl
# Roles needed:
- roles/logging.logWriter            # Write logs to Cloud Logging
- roles/monitoring.metricWriter      # Write metrics to Cloud Monitoring
- roles/secretmanager.secretAccessor # Read app secrets (DB creds, API keys)
- roles/storage.objectViewer         # Read from GCS if needed
```

#### vpn-operator (VPN Management *optional*)
```hcl
# Roles needed:
- roles/compute.vpnAdmin             # Manage VPN gateways/tunnels
- roles/secretmanager.secretAccessor # Read VPN PSK
```

---

### 5.2 Custom Roles (If Needed)

**Example: Reduced Terraform Role**
```hcl
# If standard roles too permissive
resource "google_iam_custom_role" "terraform_minimal" {
  role_id = "terraformMinimal"
  title   = "Terraform Minimal Deployment Role"
  permissions = [
    "compute.networks.create",
    "compute.networks.get",
    "compute.subnetworks.create",
    "compute.subnetworks.update",
    "compute.firewalls.create",
    "compute.routes.create",
    # ... granular permissions only
  ]
}
```

---

## 6. Audit & Logging

### 6.1 Cloud Audit Logs

**Admin Activity Logs:**
- VPC creation/modification
- Service account creation/modification
- IAM role assignments
- Secret creation/access
- Apigee org/environment changes

**Data Access Logs (optional, verbose):**
- Service account key access
- Secret Manager reads
- Cloud Run invocations
- GCS object access

**System Event Logs:**
- VPN tunnel state changes
- LB health check failures
- Cloud Run deployment events

**Enforcement:**
```hcl
# Terraform configuration for Cloud Logging sink
resource "google_logging_project_sink" "audit_sink" {
  name        = "audit-logs-sink"
  destination = "storage.googleapis.com/audit-logs-bucket"
  
  filter = ""
  # Captures all Admin Activity by default
  include_children = true
}
```

---

### 6.2 Application Logs

**Apigee Policies:**
- Log all authenticated requests (with bearer token obscured)
- Log policy execution details and target endpoint calls
- Log authentication failures (blocked requests)

**Cloud Run Services:**
- Structured logging (JSON format)
- Include request ID, user (from JWT), response status, latency
- Log any authorization failures

**Example (Python):**
```python
import logging
import json
from flask import request

logger = logging.getLogger(__name__)

@app.route('/api/resource', methods=['GET'])
def get_resource():
    user_email = request.headers.get('X-User-Email')
    logger.info(json.dumps({
        'action': 'get_resource',
        'user': user_email,
        'ip': request.remote_addr,
        'status': 200
    }))
    return {'data': 'resource'}
```

---

## 7. Network Security Policies

### 7.1 Cloud Armor Rules

**DDoS Protection:**
- Adaptive DDoS protection (automatic, no configuration needed)
- Rate limiting by client IP (e.g., 100 requests/second per IP)

**WAF Rules:**
- SQL injection prevention
- XSS prevention
- Insecure request patterns
- Geo-blocking (if required, e.g., block non-approved countries)

**Priority Rules (evaluated top-to-bottom):**
```
1. Allow: Requests from internal cloud CIDR (10.20.0.0/16, 10.80.0.0/16)
2. Block: SQL injection patterns
3. Block: XSS patterns
4. Rate limit: >100 req/sec per IP
5. Allow: All other requests (default allow)
6. Custom deny: Blocked countries (if applicable)
```

---

### 7.2 VPC Firewall Rules

**Ingress Rules:**

| Name | Priority | Direction | Source | Protocol/Port | Target | Action |
|---|---|---|---|---|---|---|
| allow-external-https | 100 | Ingress | 0.0.0.0/0 | TCP:443 | lb-backend-neg | Allow |
| allow-internal-backends | 101 | Ingress | 10.80.0.0/16 | TCP:8080 | cloud-run | Allow |
| allow-health-checks | 102 | Ingress | 35.191.0.0/16 | TCP:8080 | cloud-run | Allow |
| deny-all-ingress | 65534 | Ingress | 0.0.0.0/0 | All | All | Deny |

**Egress Rules:**

| Name | Priority | Direction | Destination | Protocol/Port | Target | Action |
|---|---|---|---|---|---|---|
| allow-backend-egress | 100 | Ingress | 10.80.0.0/16 | TCP:443 | cloud-run | Allow |
| allow-dns-egress | 101 | Egress | 0.0.0.0/0 | UDP:53 | cloud-run | Allow |
| allow-https-egress | 102 | Egress | 0.0.0.0/0 | TCP:443 | cloud-run | Allow |

---

## 8. Security Summary

| Layer | Mechanism | Strength |
|---|---|---|
| Edge | Cloud Armor (DDoS, WAF) | High — Stops common attacks at edge |
| External Transport | HTTPS (TLS 1.2+) | High — Industry standard, managed certs |
| External Auth | OAuth 2.0 / PKCE / mTLS | High — Token-based, signature verified |
| API Policies | Apigee RBAC, rate limiting | Medium-High — Depends on policy configuration |
| Backend Auth | Workload Identity + mTLS | High — No key exposure, automatic tokens |
| Backend Transport | HTTPS (TLS 1.2+) | High — Private LB + Cloud Run encryption |
| VPN Transport | IPSec IKEv2 + AES-256-GCM | High — Military-grade encryption |
| Secrets | Secret Manager + audit logs | High — Encrypted, access logged |
| IAM | Least-privilege service accounts | High — Fine-grained permissions |
| Audit | Cloud Audit Logs | High — Complete record of actions |

---

## 9. Security Validation Checklist

- [ ] All external traffic flows through Cloud Armor
- [ ] JWT tokens validated before backend invocation
- [ ] Rate limiting enforced per user/API key
- [ ] Workload Identity used for service-to-service auth (no static keys)
- [ ] VPN PSK rotated every 90 days
- [ ] All secrets in Secret Manager (not in code/Terraform)
- [ ] TLS 1.2+ enforced on all connections
- [ ] Certificate rotation automated (if Google-managed)
- [ ] IAM roles assigned with least privilege
- [ ] Audit logs enabled for admin actions and data access
- [ ] Firewall rules deny by default (except for explicitly allowed)
- [ ] On-premises authentication verified (certificate or PSK exchange) — authentication, authorization, TLS, secrets, IAM, WAF, and logging.

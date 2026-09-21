################################################################################
# Security Module — API Spoke VPC
# Purpose: Implement the security layer for the Apigee Challenge architecture
# including Cloud Armor WAF, firewall rules, IAM, and VPC Service Controls.
################################################################################


# Overview

This Terraform module implements a zero-trust security layer for the API spoke VPC, ensuring that:

- **Perimeter Security**: Cloud Armor WAF protects the external entry point with OWASP Top 10 rules
- **Network Security**: Deny-all default with explicit allow-list for documented traffic flows
- **Identity Security**: Least-privilege IAM for Cloud Run, Apigee, and administrators
- **Confidentiality**: TLS/IPSec encryption for all traffic segments
- **Auditability**: Comprehensive logging for compliance and incident investigation



## Architecture Alignment

The security module implements decisions from the Apigee Challenge architecture:

| Decision | Implementation |
|---|---|
| **Decision 1: Cloud Armor + Regional LB** | WAF policy with OWASP rules attached to regional ALB for external ingress protection |
| **Decision 2: Non-VPC-Peering Model** | PSC service attachments and firewall rules enforce customer/provider boundary; Apigee remains outside customer VPC |
| **Decision 3: Deny-All Default** | Firewall rules follow zero-trust principle: default deny ingress/egress, with explicit allow for 8 documented traffic flows |
| **Decision 4: Least-Privilege IAM** | Separate service accounts for Cloud Run (backend workload) and Apigee (admin plane) with minimal required roles |
| **Decision 5: Encrypted Transit** | All traffic encrypted: HTTPS (LB), Private Google network (PSC), IPSec (VPN) |


## Featured Security Components


### 1. Cloud Armor WAF Policy

Protects the regional external Application Load Balancer with preconfigured rules:

| Rule | Coverage | OWASP Mapping |
|---|---|---|
| Rule 100 | XSS (Cross-Site Scripting) | A03:2021 Injection |
| Rule 101 | SQL Injection | A03:2021 Injection |
| Rule 102 | Local File Inclusion (LFI) | A04:2021 Insecure Design |
| Rule 103 | Remote Code Execution (RCE) | A03:2021 Injection |
| Rule 104 | HTTP Protocol Violations | A07:2021 Cross-Site Request Forgery (CSRF), Protocol Attacks |
| Rule 105 | Scanner/Bot Detection | A07:2021 Automated Threats |
| Rule 106 (optional) | Rate Limiting | A14:2021 Rate Limiting |

**Configuration:**
- Default rule action: Allow (configurable via `cloud_armor_default_rule_action`)
- Preconfigured rules can operate in:
  - **Production**: Rules actively deny (action: deny(403))
  - **Preview**: Rules log only without blocking (preview: true)
- Rate limiting: Optional DDoS rate-limiting at action 106 with configurable threshold

**Attach to Load Balancer:**
```hcl
resource "google_compute_region_backend_service" "api_backend" {
  security_policy = module.security.cloud_armor_policy_self_link
  ...
}
```


### 2. Firewall Rules (8 flows)

All rules include logging (`INCLUDE_ALL_METADATA`) for audit and incident investigation.

#### Default Rules (Priority 65534)
- **default_deny_ingress**: Deny all ingress traffic (catch-all deny rule)
- **default_deny_egress** (optional): Deny all egress traffic

#### Allow Rules (Priority 1000-1004)

| Flow | Source | Destination | Ports | Priority | Purpose |
|---|---|---|---|---|---|
| 1a | GCP Health Check Ranges (35.191.0.0/16, 130.211.0.0/22) | API Private Subnet | 80, 443, 8080 | 1000 | Health checks from LB to backends |
| 1b | Proxy-Only Subnet | API Private Subnet | 80, 443, 8080, 9000 | 1001 | Regional ALB proxy → backends |
| 2a | Proxy-Only Subnet | [PSC traffic handled by private Google network] | 443 | 1002 | ALB northbound to Apigee runtime |
| 2b | PSC NAT Subnet | API Private Subnet | 80, 443, 8080 | 1003 | Apigee southbound to service attachment |
| 3 | API Private Subnet | Hub VPC (10.20.0.0/16) + On-Prem (10.0.0.0/12) | 443, 3306, 5432, 1433 + 0-65535 | EGRESS 1000 | Backends to external/on-prem backends |
| 4 | Hub VPC + On-Prem | API Private Subnet | All | 1004 | Return traffic from on-premises |
| 5 | All subnets | 0.0.0.0/0 | 53 (UDP/TCP) | EGRESS 1001 | DNS queries (service discovery) |
| 6 | API Private Subnet | 169.254.169.254/32 | 80 | EGRESS 1002 | GCP Metadata service (workload identity) |

**Traffic Flow Diagram:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    API SPOKE VPC FIREWALL FLOWS                   │
└─────────────────────────────────────────────────────────────────┘

INPUT:  External Client
        │
        ▼
RULE 1a ┌────────────────────────────────┐
       → │ Health Checks → Backend       │ ALLOW
         │ (GCP ranges → 80,443,8080)    │
         └────────────────────────────────┘
        
INPUT:  Regional LB (Proxy-Only Subnet)
        │
        ▼
RULE 1b ┌────────────────────────────────┐
       → │ LB Proxy → Backend            │ ALLOW
         │ (Proxy → Private, 80-9000)    │
         └────────────────────────────────┘
        
INPUT:  Apigee Runtime (PSC Northbound)
        │
        ▼
RULE 2a ┌────────────────────────────────┐
       → │ ALB → Apigee (via PSC)        │ ALLOW
         │ Private Google network        │
         └────────────────────────────────┘
        
INPUT:  Apigee Runtime (PSC Southbound)
        │
        ▼
RULE 2b ┌────────────────────────────────┐
       → │ Apigee → Service Attachment   │ ALLOW
         │ (PSC NAT subnet → Private)    │
         └────────────────────────────────┘
        
OUTPUT: Backend → External
        │
        ▼
RULE 3  ┌────────────────────────────────┐
       → │ Backend → Hub/On-Prem         │ ALLOW
         │ (Private → Hub/OnPrem, ports) │
         └────────────────────────────────┘
        
RETURN: Hub/On-Prem → Backend
        │
        ▼
RULE 4  ┌────────────────────────────────┐
       → │ On-Prem/Hub → Backend         │ ALLOW
         │ (All traffic return path)     │
         └────────────────────────────────┘

DEFAULT (65534): ┌──────────────────────┐
                → │ DENY ALL (catch-all) │ DENY
                  └──────────────────────┘
```

### 3. IAM Service Accounts

#### Cloud Run Service Account
**Purpose**: Runtime identity for Cloud Run backend workloads

**Permissions** (Least Privilege):
- `roles/secretmanager.secretAccessor`: Read secrets from Secret Manager
- `roles/logging.logWriter`: Write application logs to Cloud Logging
- `roles/monitoring.metricWriter`: Emit custom metrics to Cloud Monitoring
- `roles/run.invoker`: Allow invocation from load balancer

**Usage in Terraform:**
```hcl
service_account_email = module.security.cloud_run_service_account_email
```

#### Apigee Admin Service Account
**Purpose**: Identity for Apigee organization and proxy administration

**Permissions**:
- `roles/apigee.admin`: Apigee organization admin (if organization ID provided)

**Usage**:
- Deploy from CI/CD pipeline
- Manage Apigee policies, API proxies, and endpoint attachments
- Audit Apigee resource changes

### 4. VPC Service Controls (Optional)

Provides a zero-trust access perimeter for restricted GCP services.

**When to Enable:**
- Production environments requiring strict API access control
- Compliance requirements (e.g., FedRAMP, HIPAA)
- Need to restrict data exfiltration to approved services

**Restricted Services (configurable):**
- `storage.googleapis.com` (Cloud Storage)
- `bigquery.googleapis.com` (BigQuery)
- `cloudkms.googleapis.com` (Cloud KMS)
- `secretmanager.googleapis.com` (Secret Manager)

**Deployment Example:**
```hcl
module "security" {
  ...
  create_vpc_service_perimeter = true
  vpc_sc_restricted_services = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "secretmanager.googleapis.com"
  ]
}
```

## Integration Points

### 1. Load Balancer Module
Attach Cloud Armor policy to the regional external ALB:
```hcl
security_policy = module.security.cloud_armor_policy_self_link
```

### 2. Cloud Run Module
Use the Cloud Run service account for workload identity:
```hcl
service_account_email = module.security.cloud_run_service_account_email
```

### 3. Apigee Module
Use the Apigee admin service account for proxy deployment and endpoint attachment configuration.

## Module Inputs

See `variables.tf` for complete list. Key inputs:

| Variable | Purpose | Default |
|---|---|---|
| `compute_project_id` | GCP project for resources | Required |
| `api_spoke_network_id` | VPC network ID from infrastructure module | Required |
| `cloud_armor_default_rule_action` | WAF default action: 'allow' or 'deny' | 'allow' |
| `firewall_enable_default_deny_ingress` | Enable deny-all ingress default | true |
| `firewall_enable_default_deny_egress` | Enable deny-all egress default | false |
| `firewall_log_config_enabled` | Enable firewall logging | true |
| `create_cloud_run_service_account` | Create Cloud Run SA | true |
| `create_apigee_admin_service_account` | Create Apigee admin SA | true |
| `create_vpc_service_perimeter` | Create VPC Service Controls perimeter | true |

## Module Outputs

The module exports:

- `cloud_armor_policy_id/name/self_link`: For attaching to load balancers
- `cloud_run_service_account_email/id`: For cloud Run binding
- `apigee_admin_service_account_email/id`: For Apigee admin operations
- `firewall_rules_summary`: Overview of deployed network policies
- `security_configuration_summary`: Full security posture snapshot
- `deployment_validation_checklist`: Operator validation steps

## Deployment and Validation

### Prerequisites
1. GCP project with Compute Engine and VPC enabled
2. API spoke VPC created (via `infrastructure` module)
3. Required service accounts (will be created by this module)

### Deploy
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Validate Deployment

**Check Cloud Armor:**
```bash
gcloud compute security-policies list
gcloud compute security-policies rules list --security-policy=api-spoke-waf-policy
```

**Check Firewall Rules:**
```bash
gcloud compute firewall-rules list --filter="network:api-spoke-vpc"
gcloud compute firewall-rules describe api-spoke-allow-health-checks
```

**Check IAM Bindings:**
```bash
gcloud iam service-accounts list --filter="displayName:cloud-run"
gcloud projects get-iam-policy $PROJECT --flatten="bindings[].members" \
  --filter="bindings.role:roles/run.invoker"
```

**Check Firewall Logs:**
```bash
gcloud logging read "resource.type=vpc_flow" --limit 10 --format=json
gcloud logging read "resource.type=http_load_balancer AND protoPayload.methodName=compute.securityPolicies.patch" --limit 10
```

## Troubleshooting

### Cloud Armor Rules Not Blocking
- Check rule action (should be `deny([code])` not `deny(403)` if custom codes needed)
- Verify rule priority is lower than default rule (65535)
- Check preview flag: if `preview = true`, rules log but don't block

### Traffic Not Reaching Backends
1. Verify allow rules are in place for the traffic flow
2. Check firewall logs: `gcloud logging read "resource.type=vpc_flow"`
3. Test connectivity from source subnet to destination subnet:
   ```bash
   gcloud compute ssh test-instance --zone=ZONE -- \
     curl -v http://BACKEND_IP:PORT/healthcheck
   ```

### Service Account Permissions Denied
- Verify role bindings: `gcloud projects get-iam-policy $PROJECT --flatten="bindings[].members"`
- Test service account directly: `gcloud auth activate-service-account --key-file=SA_KEY.json`

## Security Best Practices

1. **Keep Cloud Armor Rules Updated**: Periodically review and update preconfigured rules versions
2. **Monitor Firewall Logs**: Set up alerts for unusual deny patterns
3. **Rotate Service Account Keys**: Use time-limited token-based auth where supported
4. **Principle of Least Privilege**: Grant only required roles; audit bindings quarterly
5. **Test Firewall Rules**: Create test VMs in target subnets and validate allow/deny behavior
6. **Enable VPC Flow Logs**: Use for forensics and network diagnostics

## Cost Implications

- **Cloud Armor**: $5-500/month depending on evaluation RPS and rule count
- **Firewall Logging**: $2 per GB of egress traffic (VPC Flow Logs)
- **VPC Service Controls**: $0.15/hour per perimeter
- **Service Accounts**: Free (IAM)

## Related Documentation

- [Apigee Challenge Architecture](../../docs/architecture/architecture.md)
- [Security Model](../../docs/security/security-model.md)
- [Architecture Decisions](../../docs/decisions/architecture-decisions.md)
- [Addressing Plan](../../docs/networking/addressing-plan.md)

## Maintenance

### Monthly
- Review Cloud Armor logs for false positives
- Check for new OWASP rule versions in GCP documentation

### Quarterly
- Audit IAM role bindings
- Review firewall rules for any unused or overly permissive rules
- Test disaster recovery scenarios (e.g., temporary firewall rule disablement)

### Annually
- Complete security assessment
- Update documentation with lessons learned
- Review third-party security guidance (NIST, CIS benchmarks)

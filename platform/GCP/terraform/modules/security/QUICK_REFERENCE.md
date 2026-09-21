################################################################################
# Security Layer — Quick Reference Guide
# For: Operators, Security Engineers, SREs
# Purpose: Understand components, verify deployment, troubleshoot issues
################################################################################

# Quick Facts

| Aspect | Details |
|---|---|
| **Module Path** | `platform/GCP/terraform/modules/security/` |
| **Lines of Code** | 1,360 (main.tf: 610, variables.tf: 200, outputs.tf: 150, README.md: 400) |
| **Resources** | 8 (1 WAF policy, 5 firewall rules, 4 IAM bindings, 1 data source) |
| **Dependencies** | `infrastructure` module (provides VPC reference) |
| **Deployment Time** | ~2-3 minutes |
| **Cost Impact** | ~$5-500/month (Cloud Armor, standard tier) + firewall logging |
| **Status** | Dev/demo ready, intentionally minimal and reproducible |

> Dev-stage note: This repository is for a development/demo environment, not a production deployment. Cloud Armor must use the `STANDARD` tier. The Cloud Armor policy and associated firewall/rule set should be kept to the minimum required to deploy the project, demonstrate the architecture, and support a short presentation/demo. Do not add broader production-grade rule sets or unnecessary custom policies beyond what is required for the exercise.

> Minimal security posture for this project: the objective is a working, understandable, reproducible demo environment. The design should include only the smallest viable WAF policy and firewall rules needed to prove traffic flow, ingress protection, and private connectivity without over-engineering for production.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY LAYER COMPONENTS                     │
└─────────────────────────────────────────────────────────────────┘

┌─ INGRESS (External Entry Point) ─────────────────────────────────┐
│                                                                    │
│  ┌──────────────────────────────────────────────────────┐        │
│  │ Cloud Armor Security Policy (WAF)                   │        │
│  │ - default rule for the demo environment             │        │
│  │ - minimal OWASP checks (XSS, SQLi)                  │        │
│  │ - no unnecessary production rule sprawl            │        │
│  └─────────────────────┬──────────────────────────────┘        │
│                        │                                         │
│                        ▼                                         │
│  [Regional External ALB] ← {Attach security_policy}             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌─ NETWORK LAYER (Minimal firewall baseline) ───────────────────────┐
│                                                                    │
│  DEFAULT: Deny all ingress (priority 65534)                     │
│  DEFAULT: Allow only required egress if enabled                 │
│                                                                    │
│  ALLOW Rules (Priority 1000-1003):                               │
│  ┌────────────────────────────────────────────────────┐         │
│  │ Rule 1: GCP Health Checks → Backends               │         │
│  │ Rule 2: Proxy-only subnet → Backends               │         │
│  │ Rule 3: Backend egress → Hub/OnPrem               │         │
│  │ Rule 4: DNS (UDP/TCP 53)                           │         │
│  │ Rule 5: Metadata service access                    │         │
│  └────────────────────────────────────────────────────┘         │
│                                                                    │
│  ✓ Rules are intentionally reduced for the dev/demo scope       │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘

┌─ IDENTITY & ACCESS (Least-Privilege IAM) ────────────────────────┐
│                                                                    │
│  ┌──────────────────────────────────────────────────┐            │
│  │ Cloud Run Service Account                        │            │
│  │ Roles:                                           │            │
│  │  - roles/secretmanager.secretAccessor           │            │
│  │  - roles/logging.logWriter                       │            │
│  │  - roles/monitoring.metricWriter                │            │
│  │  - roles/run.invoker                            │            │
│  │                                                  │            │
│  │ Usage: Workload identity for backend containers │            │
│  └──────────────────────────────────────────────────┘            │
│                                                                    │
│  ┌──────────────────────────────────────────────────┐            │
│  │ Apigee Admin Service Account                     │            │
│  │ Roles:                                           │            │
│  │  - roles/apigee.admin                           │            │
│  │                                                  │            │
│  │ Usage: Deploy proxies, manage endpoint attachments │        │
│  └──────────────────────────────────────────────────┘            │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘

## Deployment Checklist

### Pre-Deployment

```bash
# 1. Verify Terraform code
cd platform/GCP/terraform
terraform fmt modules/security/

# 2. Check variables are set
grep -A3 "hub_vpc_cidr\|onpremises_cidr" variables.tf

# 3. Verify infrastructure module is deployed first
terraform state list | grep infrastructure
```

### Deployment

```bash
# 1. Plan (review all resources)
terraform plan -var-file=environments/DEV/dev.tfvars -out=tfplan

# 2. Show the security module specifically
terraform show tfplan | grep -A5 "google_compute_security_policy\|google_compute_firewall"

# 3. Apply
terraform apply tfplan
```

### Post-Deployment Validation

#### Check 1: Cloud Armor Policy
```bash
gcloud compute security-policies describe api-spoke-waf-policy --project=$PROJECT

# Verify the default rule plus the minimal OWASP checks (XSS, SQLi):
gcloud compute security-policies rules list \
  --security-policy=api-spoke-waf-policy --project=$PROJECT \
  --format="table(priority, action, description)"

# Expected output: a small set of demo rules, not a large production rule set.
```

#### Check 2: Firewall Rules
```bash
# List all firewall rules in API spoke VPC
gcloud compute firewall-rules list \
  --filter="network:api-spoke-vpc" \
  --project=$PROJECT \
  --format="table(name, direction, priority, sourceRanges[0], destinationRanges[0], allowed[0].map().firewall_rule())"

# Expected: a minimal set of required rule(s) for the dev/demo environment
# This is intentionally smaller than a full production baseline.
gcloud compute firewall-rules list \
  --filter="network:api-spoke-vpc" \
  --project=$PROJECT | wc -l
# Should show the reduced rule count for the demo deployment.
```

#### Check 3: IAM Service Accounts
```bash
# List service accounts
gcloud iam service-accounts list \
  --filter="email:cloud-run-backend-sa@ OR email:apigee-admin-sa@" \
  --project=$PROJECT \
  --format="table(email)"

# Verify Cloud Run SA roles
gcloud projects get-iam-policy $PROJECT \
  --flatten="bindings[].members" \
  --filter="bindings.members:cloud-run-backend-sa@" \
  --format="table(bindings.role)"

# Expected roles:
# - roles/logging.logWriter
# - roles/monitoring.metricWriter
# - roles/secretmanager.secretAccessor
# - roles/run.invoker
```

#### Check 4: Firewall Logging
```bash
# View recent firewall logs
gcloud logging read "resource.type=vpc_flow" \
  --limit=5 --project=$PROJECT --format=json | \
  jq '.[] | {src: .jsonPayload.srcAddr, dst: .jsonPayload.destAddr, disposition: .jsonPayload.disposition}'

# View Cloud Armor logs
gcloud logging read "resource.type=http_load_balancer" \
  --limit=5 --project=$PROJECT --format=json | \
  jq '.[] | {severity: .severity, message: .jsonPayload.enforcedSecurityPolicy}'
```

## Common Operations

### Enable Preview Mode for Cloud Armor Rules (Testing)
```bash
# Edit variables in infrastructure.tf:
cloud_armor_enable_preview_rules = true

# Apply changes
terraform apply

# Rules will log instead of block (safe for testing WAF rules)
```

### Adjust Rate Limiting Threshold
```bash
# Edit in infrastructure.tf:
cloud_armor_rate_limit_options = {
  enable_rate_limiting = true
  max_rate_per_ip      = 5000      # Lower threshold (was 10000)
  ban_duration_seconds = 300       # Shorter ban (was 600)
}

terraform apply
```

### Attach Cloud Armor Policy to Load Balancer
```hcl
# In load balancer module (not yet implemented):
resource "google_compute_region_backend_service" "api_backend" {
  name            = "api-backend-service"
  project         = var.compute_project_id
  region          = var.compute_region
  protocol        = "HTTPS"
  
  # Attach Cloud Armor policy
  security_policy = module.security.cloud_armor_policy_self_link
  
  # ... rest of configuration
}
```

### Enable VPC Service Controls (Production)
```hcl
# In infrastructure.tf:
module "security" {
  # ...
  create_vpc_service_perimeter = true
  vpc_sc_restricted_services = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "secretmanager.googleapis.com"
  ]
}

terraform apply
```

## Troubleshooting

### Problem: "Cloud Armor rules are not blocking malicious traffic"

**Cause 1**: Rules in preview mode (logging only, not blocking)
```bash
# Check if preview mode is enabled
terraform show tfplan | grep "preview = true"

# Solution: Disable preview mode in Terraform
cloud_armor_enable_preview_rules = false

terraform apply
```

**Cause 2**: Rule priority higher than 65535 (default rule takes precedence)
```bash
# Cloud Armor rules are guaranteed to have priority < 65535
# Default rule is always 65535
# Solution: No action needed, rules are correctly prioritized
```

**Cause 3**: Rule attached to wrong load balancer or not attached at all
```bash
# Verify policy is attached to backend service
gcloud compute backend-services describe api-backend-service \
  --region=$REGION --project=$PROJECT | grep securityPolicy

# Should show the policy self-link:
# securityPolicy: https://www.googleapis.com/compute/v1/projects/.../global/securityPolicies/api-spoke-waf-policy
```

### Problem: "Traffic is being blocked by firewall when it shouldn't be"

**Diagnosis**:
```bash
# View denied traffic in VPC Flow Logs
gcloud logging read "resource.type=vpc_flow AND jsonPayload.disposition=DENY" \
  --limit=10 --project=$PROJECT --format=json | \
  jq '.[] | {src: .jsonPayload.srcAddr, dst: .jsonPayload.destAddr, srcPort: .jsonPayload.srcPort, destPort: .jsonPayload.destPort}'

# Map the source and destination to the firewall rules
# Compare against the 8 allow rules to identify which traffic is missing
```

**Solution**:
```bash
# Add explicit allow rule for the missing traffic flow
# Follow the same pattern as existing rules (deny-all default → explicit allow)
# Update infrastructure.tf with new rule, then terraform apply
```

### Problem: "Service account cannot access secrets/logs"

**Diagnosis**:
```bash
# Verify role binding
gcloud projects get-iam-policy $PROJECT \
  --flatten="bindings[].members" \
  --filter="bindings.members:cloud-run-backend-sa@" \
  --format="table(bindings.role)"

# Expected: roles/secretmanager.secretAccessor, roles/logging.logWriter, etc.
```

**Solution**:
```bash
# If roles are missing, reapply the security module
terraform apply -target=module.security

# If roles are present but still denied, check Secret Manager IAM policy
gcloud secrets get-iam-policy SECRET_NAME --project=$PROJECT
```

## Integration Points

### For Load Balancer Module
```hcl
security_policy = module.security.cloud_armor_policy_self_link
```

### For Cloud Run Module
```hcl
service_account_email = module.security.cloud_run_service_account_email
```

### For Apigee Module
```hcl
admin_service_account_email = module.security.apigee_admin_service_account_email
```

### For Observability Module
```hcl
# Both modules write logs to Cloud Logging
# Security module: Cloud Armor logs, VPC Flow Logs, IAM audit logs
# Observability module: ALB logs, Apigee analytics, Cloud Run metrics
# Log aggregation happens in Cloud Logging sink (configure separately)
```

## Maintenance Schedule

### Daily
- Review Cloud Armor logs: `gcloud logging read "resource.type=http_load_balancer"`
- Alert on unusual deny patterns (more than 10x baseline)

### Weekly
- Review firewall rule changes: `gcloud logging read "protoPayload.methodName:compute.firewalls"`
- Verify no manual firewall rules were added outside Terraform

### Monthly
- Check for new Cloud Armor rule versions: `gcloud compute security-policies describe-new-version`
- Review rate limiting threshold: is it catching legitimate traffic?

### Quarterly
- Audit IAM role bindings: `gcloud projects get-iam-policy`
- Test disaster recovery: temporarily disable default deny rule, ensure traffic flows, then re-enable

### Annually
- Review security posture against latest NIST/CIS guidelines
- Evaluate new GCP security services (e.g., Security Service Edge, Cloud IDS)
- Update documentation with lessons learned

## Cost Optimization

| Component | Cost | Optimization |
|---|---|---|
| Cloud Armor | $5/month base + $2/million rules evaluated | Use preconfigured rules only; avoid custom rules if possible |
| Firewall rules | Free (8 rules) | Base cost is per rule; more rules = more compute overhead |
| Firewall logging | $2/GB egress | Export to GCS for long-term retention (cheaper than Cloud Logging) |
| VPC Flow Logs | $2/GB | Only enable for critical subnets; disable for internal routing |
| Service accounts | Free | Use workload identity (free) instead of service account keys |

## Reference Documentation

- **Module README**: `platform/GCP/terraform/modules/security/README.md`
- **Security Model**: `docs/security/security-model.md`
- **Architecture Decisions**: `docs/decisions/architecture-decisions.md`
- **Addressing Plan**: `docs/networking/addressing-plan.md`
- **GCP Documentation**: 
  - [Cloud Armor](https://cloud.google.com/armor/docs)
  - [VPC Firewall Rules](https://cloud.google.com/vpc/docs/firewalls)
  - [Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
  - [VPC Service Controls](https://cloud.google.com/vpc-service-controls/docs)

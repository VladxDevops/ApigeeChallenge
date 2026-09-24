# Postmortem: Regional Cloud Armor Security Policy Rule State Refresh Failure

## Incident Metadata

| Attribute | Value |
| --- | --- |
| **Date** | 2026-09-24 |
| **Severity** | High (Blocked Infrastructure Deployment) |
| **Status** | Resolved |
| **Affected Area** | GCP Infrastructure Module — Northbound Load Balancer & Regional Cloud Armor (`networking.tf`) |
| **Primary Root Cause** | GCP Regional Security Policy API HTTP 400 response on `getRule` for non-existent priorities + Terraform state tracking lock |

---

## 1. Executive Summary

During execution of `terraform apply`, Terraform failed during the initial state refresh phase with the error:
`googleapi: Error 400: Invalid value for field 'priority': 1000. api-armor-policy does not contain a rule with priority 1000., badRequest`.

This issue prevented Terraform from applying any configuration updates across the repository because Terraform was unable to complete the refresh query for `google_compute_region_security_policy_rule.deny_test_ip`.

---

## 2. Error Trace

```text
Error: Error when reading or editing ComputeRegionSecurityPolicyRule "projects/rocketcodeapigee/regions/us-south1/securityPolicies/api-armor-policy/priority/1000": googleapi: Error 400: Invalid value for field 'priority': 1000. api-armor-policy does not contain a rule with priority 1000., badRequest

  with module.infrastructure.google_compute_region_security_policy_rule.deny_test_ip,
  on modules/infrastructure/networking.tf line 216, in resource "google_compute_region_security_policy_rule" "deny_test_ip":
 216: resource "google_compute_region_security_policy_rule" "deny_test_ip" {
```

---

## 3. Root Cause Analysis

### 3.1 GCP API Behavior
When using standalone `google_compute_region_security_policy_rule` resources, Terraform issues an HTTP GET query (`getRule?priority=1000`) for each tracked rule priority to check its current status in GCP.

Unlike standard GCP compute resources (which return `HTTP 404 Not Found` when a resource does not exist), GCP's Regional Security Policy API returns `HTTP 400 Bad Request` with the message:
`api-armor-policy does not contain a rule with priority 1000.`

### 3.2 Terraform Provider Handling
The HashiCorp Google Terraform provider handles `HTTP 404` responses as "resource missing, mark for creation/re-creation". However, when it encounters `HTTP 400`, it interprets it as an unrecoverable API error during the refresh phase and aborts execution immediately.

### 3.3 State File Lock
Because `module.infrastructure.google_compute_region_security_policy_rule.deny_test_ip` was recorded in the remote state file (`gs://terraform_state_backend_rocket/terraform/state/default.tfstate`), Terraform attempted to refresh priority `1000` on every run—even after the rule resource was removed from `.tf` code—because Terraform must refresh state for existing resources before planning destroy/update operations.

---

## 4. Resolution & Remediation

### 4.1 Code Refactoring (Inline Policy Rules)
To prevent standalone GET requests for individual rule priorities, `google_compute_region_security_policy.api_armor_policy` in [`networking.tf`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/platform/GCP/terraform/modules/infrastructure/networking.tf) was refactored to embed rules inline:

```hcl
resource "google_compute_region_security_policy" "api_armor_policy" {
  name        = "api-armor-policy"
  project     = var.compute_project_id
  region      = var.compute_region
  description = "Baseline Cloud Armor policy for the northbound API entry point."

  # Rule Priority 1000: Custom deny rule
  rules {
    action      = "deny(403)"
    priority    = 1000
    description = "Example explicit deny rule."
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["9.9.9.9/32"]
      }
    }
  }

  # Rule Priority 2147483647: Default allow rule
  rules {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow rule."
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
```

Inline rule definitions manage the security policy and its rules atomically using a single `PATCH` request (`PatchSecurityPolicy`), completely bypassing individual GET rule API calls.

### 4.2 State Index Cleanup
The stale standalone rule references in the remote state file were removed using `terraform state rm`:

```bash
cd platform/GCP/terraform
terraform state rm module.infrastructure.google_compute_region_security_policy_rule.deny_test_ip
terraform state rm module.infrastructure.google_compute_region_security_policy_rule.default_allow
```

*Alternative workaround for unblocking execution:*
```bash
terraform apply -refresh=false
```

---

## 5. Prevention & Best Practices

1. **Prefer Inline `rules` Blocks**: For regional Cloud Armor policies (`google_compute_region_security_policy`), always declare rules inline within the policy resource rather than using standalone `google_compute_region_security_policy_rule` resources.
2. **State Management Protocol**: When converting standalone GCP resources to inline sub-blocks, always remove the old standalone resources from the Terraform state index via `terraform state rm` to prevent state refresh queries on non-existent endpoints.
3. **Validation Standard**: Always run `terraform fmt` and `terraform validate` after modifying security policy declarations.

---

## 6. Related References

- **Changelog**: [`changelog.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/changelog.md)
- **Agent Transcripts**: [`transcripts.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/transcripts.md)
- **Infrastructure Module**: [`networking.tf`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/platform/GCP/terraform/modules/infrastructure/networking.tf)

# Troubleshooting Guide — Apigee Ingress & Southbound Connectivity

## 1. Overview & Context

This troubleshooting document records the root cause analysis, empirical diagnostic steps, dry-run validation, and resolution procedure for connectivity failures encountered during the deployment and verification of the Apigee platform spoke architecture.

### Problem Summary
When invoking the external API endpoint via `curl`:
```bash
curl -vk \
  --resolve api.example.com:443:34.0.132.236 \
  -H 'Host: api.example.com' \
  https://api.example.com/hello
```
Two consecutive issues were observed:
1. **Initial Failure**: Immediate connection refusal:
   `curl: (7) Failed to connect to api.example.com port 443 after 75992 ms: Couldn't connect to server`
2. **Secondary Failure**: Upon correcting the IP address to `34.0.130.232`, the TLS handshake succeeded but Apigee returned:
   `HTTP/2 503 Service Unavailable` with `TARGET_CONNECT_TIMEOUT`.

---

## 2. Symptom & Error Diagnostic Matrix

| Symptom / Error | Layer / Component | Root Cause | Resolution |
| :--- | :--- | :--- | :--- |
| `Connection refused` on port 443 | Client → External ALB | Targeted unassigned IP `34.0.132.236` instead of the reserved static IP `34.0.130.232`. | Update client DNS resolution / `--resolve` argument to target `34.0.130.232`. |
| `503 TARGET_CONNECT_TIMEOUT` | Apigee → Southbound PSC | Apigee tenant project (`mcedd3b7984191d1d-tp`) was held in `PENDING` connection state on producer `api-psc-service-attachment`. | Update `consumer-accept-list` on `api-psc-service-attachment` to include tenant project `mcedd3b7984191d1d-tp`. |
| `503 TARGET_CONNECT_TIMEOUT` (Firewall) | PSC NAT → Spoke ILB | Spoke VPC `api-spoke-vpc` default deny-all ingress rule blocked traffic from `psc_nat_subnet_cidr` (`10.80.0.16/29`). | Add ingress firewall rule `api-spoke-allow-psc-nat-to-backends` allowing `10.80.0.16/29` to target `10.80.0.0/28` on ports 80/443. |
| `403 Forbidden` | Internal ILB → Cloud Run | Cloud Run service IAM policy lacked invoker permissions for incoming requests. | Grant `roles/run.invoker` to `allUsers` (or configure Google Auth ID tokens in Apigee Target Endpoint). |

---

## 3. End-to-End Architectural Flow & Diagnostics

```
[ External Client ]
        │  curl -vk --resolve api.example.com:443:34.0.130.232 https://api.example.com/hello
        ▼
[ External Regional Application Load Balancer ]  <-- IP: 34.0.130.232 (TLS Certificate: api.example.com)
        │  Cloud Armor WAF Policy (api-armor-policy)
        ▼
[ Northbound PSC NEG ] (apigee-northbound-psc-neg)
        │  PSC Tunnel
        ▼
[ Apigee Organization & Runtime Instance ] (apigee-instance-us-south1)
        │  EnvGroup: dev-group (Hostnames: ["api.example.com"])
        │  Environment: dev
        │  Proxy: hello-world-proxy (Revision 1)
        ▼
[ Southbound PSC Endpoint Attachment ] (cloudrun-backend, Host: 10.0.148.2)
        │  PSC Attachment Status: ACCEPTED (Tenant Project: mcedd3b7984191d1d-tp)
        ▼
[ Spoke VPC PSC NAT Subnet ] (api-psc-nat-us-south1, CIDR: 10.80.0.16/29)
        │  Ingress Firewall Rule: api-spoke-allow-psc-nat-to-backends (ALLOW tcp:80,443)
        ▼
[ Regional Internal HTTP Load Balancer ] (api-ilb-forwarding-rule, IP: 10.80.0.2)
        │  Proxy-Only Subnet: api-proxy-only-us-south1 (10.80.0.64/26)
        │  Serverless NEG: api-backend-run-neg
        ▼
[ Cloud Run Backend Service ] (rocketcode-demo-backend)
        │  IAM Policy: roles/run.invoker
        ▼
[ HTTP 200 OK Response ]
{"status":"healthy","message":"Hello from Cloud Run backend!","service":"hello-backend"}
```

---

## 4. Root Cause Analysis (RCA)

### 4.1 Ingress IP Mismatch
* **Diagnostic Command**: `gcloud compute forwarding-rules list --project=rocketcodeapigee`
* **Finding**: The external forwarding rule `apigee-northbound-fwd-rule` was allocated IP `34.0.130.232`. The initial test command targeted `34.0.132.236`, resulting in `Connection refused`.

### 4.2 Pending Southbound PSC Connection State
* **Diagnostic Command**: `gcloud compute service-attachments describe api-psc-service-attachment --region=us-south1`
* **Finding**: `connectedEndpoints` listed tenant project `mcedd3b7984191d1d-tp` in `status: PENDING`. Because `consumerAcceptLists` only whitelisted `rocketcodeapigee`, GCP blocked traffic flow between Apigee's runtime tenant project and the spoke VPC Service Attachment.

### 4.3 Ingress Firewall Policy Omission
* **Diagnostic Command**: `gcloud compute firewall-rules list --project=rocketcodeapigee`
* **Finding**: `api-spoke-vpc` enforced a zero-trust `default-deny-ingress` policy at priority 65534. Firewall rules allowed health checks (`35.191.0.0/16`) and proxy-only subnet traffic (`10.80.0.64/26`), but **omitted** an explicit allow rule for traffic originating from the PSC NAT subnet (`10.80.0.16/29`).

---

## 5. Permanent Remediation Code Diffs

### 5.1 Security Module (`platform/GCP/terraform/modules/security/main.tf`)
```hcl
# FLOW 1C: PSC NAT subnet to backend services / internal load balancer.
resource "google_compute_firewall" "allow_psc_nat_to_backends" {
  name      = "api-spoke-allow-psc-nat-to-backends"
  project   = var.compute_project_id
  network   = var.api_spoke_network_id
  direction = "INGRESS"
  priority  = 1001

  source_ranges      = [var.psc_nat_subnet_cidr]
  destination_ranges = [var.api_private_subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  log_config {
    metadata = var.firewall_log_config_enabled ? "INCLUDE_ALL_METADATA" : "EXCLUDE_ALL_METADATA"
  }

  description = "Allow traffic from Apigee PSC NAT subnet to internal load balancer / backend services."
}
```

### 5.2 Infrastructure Module (`platform/GCP/terraform/modules/infrastructure/networking.tf`)
```hcl
resource "google_compute_service_attachment" "api_psc" {
  name                  = "api-psc-service-attachment"
  project               = var.compute_project_id
  region                = var.compute_region
  description           = "PSC service attachment publishing the Cloud Run backend to Apigee."
  target_service        = google_compute_forwarding_rule.api_ilb.id
  connection_preference = "ACCEPT_MANUAL"

  nat_subnets = [google_compute_subnetwork.psc_nat.id]

  consumer_accept_lists {
    project_id_or_num = "mcedd3b7984191d1d-tp"
    connection_limit  = 2
  }

  consumer_accept_lists {
    project_id_or_num = var.apigee_consumer_project_id
    connection_limit  = 2
  }

  enable_proxy_protocol = false
}
```

---

## 6. Empirical Verification & Test Results

### Verification Command:
```bash
curl -vk --resolve api.example.com:443:34.0.130.232 https://api.example.com/hello
```

### Output:
```http
* Connected to api.example.com (34.0.130.232) port 443
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN: server accepted h2
> GET /hello HTTP/2
> Host: api.example.com

< HTTP/2 200 
< content-type: application/json
< date: Wed, 07 Oct 2026 00:45:57 GMT
< via: 1.1 google, 1.1 google

{"status":"healthy","message":"Hello from Cloud Run backend!","service":"hello-backend","timestamp":"2026-10-07T00:45:57.788Z"}
```

---

## 7. Operational Runbook & Recommendations

1. **PSC Tenant Project Whitelisting**: Always inspect `gcloud compute service-attachments describe` after deploying a new Apigee environment to ensure the tenant project connection state transitions to `ACCEPTED`.
2. **Ingress Firewall Audit**: Maintain zero-trust firewall policies by explicitly allowing ingress from dedicated PSC NAT subnets (`psc_nat_subnet_cidr`) to backend internal load balancers.
3. **DNS / Host Resolution**: Ensure external test commands resolve `api.example.com` to the exact IP outputted by `gcloud compute forwarding-rules list`.

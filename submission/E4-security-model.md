# E4 — Security Model — Apigee Challenge

## 1. Security Overview

The security model enforces zero-trust principles, least-privilege access, edge threat protection, and private cross-boundary connectivity.

## 2. Security Controls

1. **Authentication & Authorization**:
   - Edge client requests authenticate via OAuth 2.0 / JWT tokens validated at the Apigee layer.
   - Service-to-service calls use IAM roles (`roles/run.invoker`) assigned to dedicated workload identities (`cloud-run-backend-sa`).

2. **Edge WAF (Cloud Armor)**:
   - Regional Cloud Armor policy attached to the Regional External ALB.
   - Includes baseline OWASP protection rules (XSS, SQLi) and rate limiting (10,000 requests/min per IP).

3. **Network Boundary Defense**:
   - Zero public IP addresses assigned to backend services.
   - Cloud Run ingress locked to `INGRESS_TRAFFIC_INTERNAL_ONLY`.
   - Deny-all ingress firewall baseline enforced on the Spoke VPC.

4. **Encryption & Secrets**:
   - Ingress TLS 1.3 terminated at the Regional ALB.
   - Internal traffic encrypted via GCP managed network encryption.
   - Secret Manager stores OAuth client secrets, DB passwords, and signing keys; zero secrets stored in code.

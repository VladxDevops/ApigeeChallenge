# Northbound Private Service Connect Architecture

## 1. Overview

The Northbound path exposes Apigee API proxies to public clients securely through a Regional External Application Load Balancer, Regional Cloud Armor (WAF), and Private Service Connect (PSC).

## 2. Ingress Traffic Flow

```text
External Public Client
       │ (HTTPS :443)
       ▼
Regional External ALB Frontend IP
       │
Regional Cloud Armor Security Policy (WAF)
       │
Regional External HTTP(S) Proxy & URL Map
       │
PSC Network Endpoint Group (NEG)
       │ (Google Private Infrastructure)
       ▼
Apigee Instance Service Attachment
       │
Apigee Managed Tenant Runtime
```

## 3. Key Components & Configuration

1. **Regional External Load Balancer**:
   - Location: `us-south1`
   - Scheme: `EXTERNAL_MANAGED`
   - Proxy-Only Subnet: `10.80.0.64/26` (`REGIONAL_MANAGED_PROXY`)

2. **Regional Cloud Armor (WAF)**:
   - Resource: `google_compute_region_security_policy.api_armor_policy`
   - Capabilities: Baseline deny-list, OWASP XSS/SQLi preconfigured rules, rate limiting (10,000 requests/min per IP).

3. **Northbound PSC Network Endpoint Group (NEG)**:
   - Resource: `google_compute_region_network_endpoint_group.apigee_psc_neg`
   - Target: `google_apigee_instance.apigee_instance.service_attachment`
   - Network Type: `PRIVATE_SERVICE_CONNECT`

4. **Security & Trust Boundary**:
   - Client traffic terminates TLS at the external ALB.
   - Traffic is filtered by Cloud Armor rules before being forwarded across the PSC attachment into the Apigee tenant.

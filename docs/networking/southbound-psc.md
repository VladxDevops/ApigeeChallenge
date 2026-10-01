# Southbound Private Service Connect Architecture

## 1. Overview

The Southbound path enables the managed Apigee runtime to privately reach customer backends (Cloud Run and hybrid on-premises services) without assigning customer IP addresses to Apigee or exposing backends to the public internet.

## 2. Egress Traffic Flow

```text
Apigee Managed Tenant Runtime
       │
Apigee Endpoint Attachment (`google_apigee_endpoint_attachment.cloud_run_backend`)
       │ (PSC Connection)
       ▼
Producer Service Attachment (`google_compute_service_attachment.api_psc`)
       │ (NAT Subnet: 10.80.0.16/29)
       ▼
Internal Regional Application Load Balancer (ILB)
       │
Serverless Network Endpoint Group (NEG)
       │
Cloud Run Backend Service (`INGRESS_TRAFFIC_INTERNAL_ONLY`)
```

## 3. Key Components & Configuration

1. **Producer Service Attachment**:
   - Resource: `google_compute_service_attachment.api_psc`
   - Location: `us-south1`
   - NAT Subnets: `10.80.0.16/29` (`psc_nat_subnet`)
   - Connection Preference: `ACCEPT_MANUAL` (restricted to authorized projects)

2. **Internal Load Balancer (ILB)**:
   - Scheme: `INTERNAL_MANAGED`
   - Target: Serverless NEG pointing to Cloud Run service

3. **Cloud Run Backend Security**:
   - Ingress Setting: `INGRESS_TRAFFIC_INTERNAL_ONLY`
   - IAM Invoker Role: Granted to service identity, preventing direct internet access.

4. **Hybrid On-Premises Branch**:
   - Traffic targeting on-prem services routes from Cloud Run / ILB through the Spoke VPC, across the HA Cloud VPN tunnel to the Hub VPC, and into the on-prem network (`10.0.0.0/12`).

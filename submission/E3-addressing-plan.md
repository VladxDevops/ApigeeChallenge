# E3 — Addressing Plan — Apigee Challenge

## 1. Subnet Addressing Plan

| Subnet Name | Purpose | CIDR Range | Size | Region | Owner / Managed By |
|---|---|---|---|---|---|
| `api-spoke-vpc` | Dedicated API Project VPC | `10.80.0.0/16` | /16 | `us-south1` | Spoke Project |
| `api-private-subnet` | Private API & Backend Subnet | `10.80.0.0/28` | /28 (16 IPs) | `us-south1` | Customer Spoke |
| `psc-nat-subnet` | Southbound PSC NAT Subnet | `10.80.0.16/29` | /29 (8 IPs) | `us-south1` | Customer Spoke / PSC |
| `regional-proxy-only` | Regional ALB Managed Proxy Subnet | `10.80.0.64/26` | /26 (64 IPs) | `us-south1` | GCP Managed LB |
| Assumed Hub VPC | Central Network Hub | `10.20.0.0/16` | /16 | Multi-region | Central IT |
| Assumed On-Prem | Legacy Data Center / Backends | `10.0.0.0/12` | /12 | On-Premises | Corporate Infra |

## 2. Non-Overlap Verification

- API Spoke VPC (`10.80.0.0/16`) does not overlap with Hub VPC (`10.20.0.0/16`) or On-Premises network (`10.0.0.0/12`).
- Apigee managed tenant project operates on Google-managed tenant IP space; no organization CIDR range is allocated to the Apigee runtime.

# E5 — Assumptions, Risks, and Trade-offs — Apigee Challenge

## 1. Key Assumptions

1. **Apigee Billing Type**: `EVALUATION` org type assumed for development/demo scope in project `rocketcodeapigee`.
2. **Region Selection**: `us-south1` selected for regional co-location of Apigee, Cloud Run, ALB, and Cloud VPN.
3. **Hub & On-Prem CIDRs**: Hub VPC assumed at `10.20.0.0/16`; On-Premises data center assumed at `10.0.0.0/12`.
4. **Hybrid Link**: IPSec HA Cloud VPN assumed as the reference hybrid connectivity mechanism for on-premises reachability.

## 2. Identified Risks & Mitigation Strategies

| Risk | Impact | Mitigation Strategy |
|---|---|---|
| Peak-hour latency on legacy on-prem backend | High latency for client requests | Use Cloud Monitoring metrics to isolate legacy latency; implement Apigee response caching. |
| PSC service attachment limit / quota exhaustion | Service connection failures | Pre-reserve PSC NAT subnets with buffer capacity (`10.80.0.16/29`). |
| Development TLS certificate invalidation | Client TLS handshake errors | Auto-generate dev self-signed certificate in Terraform; substitute managed cert in production. |

## 3. Architecture Trade-offs

- **PSC vs. VPC Peering**: PSC introduces service attachment configuration complexity but completely avoids Apigee CIDR allocation and VPC peering routing risks.
- **Regional vs. Global ALB**: Regional ALB restricts deployment scope to `us-south1` and simplifies Cloud Armor policy management, whereas Global ALB would provide multi-region failover at higher cost/complexity.

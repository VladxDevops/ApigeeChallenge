# E1 — End-to-end architecture (text)

This is the filled-in version of the Rocket Code context diagram. The box that was `ZONA A DISEÑAR` is Private Service Connect in both directions. Arrows are request direction. Responses travel back on the same private path. Region is `us-south1`.

```text
                         [ Clientes externos ]
                         TRUST 0 · Internet
                                    |
                              HTTPS :443
                           DNS api.example.com
                                    |
                                    v
      +------------------------------------------------------------------+
      | NEW  Proyecto de APIs · spoke          customer project          |
      |      us-south1                                                   |
      |                                                                  |
      |   [ Punto de entrada externo · WAF ]                             |
      |   Regional External Application LB                               |
      |   apigee-northbound-fwd-rule + Cloud Armor (api-armor-policy)    |
      |   Proxy-only subnet api-proxy-only-us-south1  10.80.0.64/26      |
      |                         |                                        |
      |                         |  northbound PSC NEG                    |
      |                         |  apigee-northbound-psc-neg              |
      +-------------------------|----------------------------------------+
                                |  TRUST 1  customer edge -> Apigee tenant
                                v
      + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
        OUTSIDE CONTROL   Tenant del proveedor · Runtime administrado
      |                   Apigee non-VPC-peering (disable_vpc_peering)  |
      |                   runtime_type CLOUD · no organization CIDR     |
        policies, authn/authz, then the target call
      |                   google_apigee_instance service attachment     |
      + - - - - - - - - - - - - - - - - - - - - - - - - | - - - - - - - - +
                                                        |  salida
                                                        |  TRUST 2  Apigee -> customer producer
                                                        v
      +------------------------------------------------------------------+
      | NEW  VPC de APIs · api-spoke-vpc · 10.80.0.0/16                  |
      |                                                                  |
      |   TRANSITION INTO THE INTERNAL NETWORK                          |
      |   PSC service attachment  api-psc-service-attachment             |
      |   NAT subnet api-psc-nat-us-south1  10.80.0.16/29                |
      |                         |                                        |
      |                         v                                        |
      |   Internal regional ALB   api-ilb-forwarding-rule                |
      |   private subnet api-private-us-south1  10.80.0.0/28             |
      |                         |                                        |
      |                         v                                        |
      |   Serverless NEG          api-backend-run-neg                    |
      +-------------------------|----------------------------------------+
                                |
                 +--------------+------------------+
                 |                                 |
                 v                                 v
      +---------------------------+     +-------------------------------+
      | NEW  Plataforma de apps   |     | Hybrid branch                 |
      | Cloud Run                 |     | spoke route toward the Hub    |
      | ingress = internal + LB   |     | no extra VPC peering          |
      | not reachable on run.app  |     +---------------+---------------+
      +-------------+-------------+                     |
                    |                                   |
                    +----------------+------------------+
                                     |
                                     |  TRUST 3  API spoke -> Hub
                                     v
      +------------------------------------------------------------------+
      | EXISTING  Hub de red · VPC central                               |
      | ASSUMPTION  10.20.0.0/16                                         |
      | HA Cloud VPN (exercise hybrid path)                              |
      +------------------------------+-----------------------------------+
                                     |  TRUST 4  GCP Hub -> on-premises
                                     v
      + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
        OUTSIDE CONTROL   On-premises · core de negocio
      | ASSUMPTION  10.0.0.0/12                                         |
      | Java application  ------>  relational database                  |
        TRUST 5  application -> data
      | Peak-hour latency lives here. The load balancer does not fix it.|
      + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
```

## Trust boundaries on this page

| Boundary | From | To |
|---|---|---|
| 0 | Internet clients | Customer API edge (external LB + Cloud Armor) |
| 1 | Customer API edge | Provider-managed Apigee tenant |
| 2 | Apigee tenant | Customer PSC service attachment in `api-spoke-vpc` |
| 3 | API spoke | Existing Hub VPC |
| 4 | Hub | On-premises |
| 5 | Java application | Relational database |

Operator access (Terraform, IAM, Apigee control plane) is a separate control-plane boundary. It is not drawn on the data path.

## Legend

| Mark | Meaning | Matches the challenge diagram |
|---|---|---|
| `NEW` | We design and own it | Continuous purple stroke |
| `EXISTING` | Already in the organization | Continuous gray stroke |
| `OUTSIDE CONTROL` | Provider tenant or on-premises | Dashed gray stroke |
| `ASSUMPTION` | Range the challenge did not give | Declared, not discovered |

## What this diagram refuses

- No public IP on Cloud Run. Ingress is `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`.
- No organization CIDR on the Apigee runtime. `disable_vpc_peering = true`.
- No extra VPC peering to make Apigee, the spoke, and the Hub transitive.
- Backends are not on the Internet. The only public hop is client to the regional external load balancer.

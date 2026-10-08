# Southbound — how traffic returns to the backends

Challenge question: **Cómo regresa el tráfico hacia los backends?** (`salida ?`).

"Regresa" here is Apigee calling a private target, not the HTTP response. The HTTP response is the last diagram on this page. Apigee never receives a customer route table. It dials one PSC endpoint attachment, and that attachment lands on a service we publish inside `api-spoke-vpc`.

```text
  + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
    Apigee runtime  (provider tenant, non-VPC-peering)
  | TargetEndpoint uses the endpoint-attachment host             |
  + - - - - - - - - - - - - - - - - - - - - - - - | - - - - - - - +
                                                  |
                                                  |  Apigee endpoint attachment
                                                  |  google_apigee_endpoint_attachment.cloud_run_backend
                                                  v
  +------------------------------------------------------------------+
  | TRUST: Apigee tenant -> customer producer                        |
  | VPC de APIs · api-spoke-vpc · us-south1                          |
  |                                                                  |
  |  PSC service attachment   api-psc-service-attachment             |
  |  connection_preference    ACCEPT_MANUAL                          |
  |  accept list              Apigee tenant project                  |
  |  NAT subnet               api-psc-nat-us-south1  10.80.0.16/29   |
  |                           purpose PRIVATE_SERVICE_CONNECT        |
  |                 |                                                |
  |                 |  source NAT into the NAT subnet                |
  |                 |  firewall api-spoke-allow-psc-nat-to-backends  |
  |                 v                                                |
  |  Internal regional Application LB                                |
  |  scheme INTERNAL_MANAGED                                         |
  |  forwarding rule  api-ilb-forwarding-rule                        |
  |  private subnet   api-private-us-south1  10.80.0.0/28            |
  |                 |                                                |
  |                 v                                                |
  |  Serverless NEG   api-backend-run-neg                            |
  +-----------------|------------------------------------------------+
                    |
          +---------+---------------------------+
          |                                     |
          v                                     v
  +-----------------------------+    +----------------------------------+
  | Cloud Run backend           |    | Hybrid branch                    |
  | ingress                     |    | private route, spoke -> Hub      |
  | INGRESS_TRAFFIC_            |    |                                  |
  | INTERNAL_LOAD_BALANCER      |    v                                  |
  | IAM roles/run.invoker       |    +----------------------------------+
  | no public run.app bypass    |    | EXISTING Hub VPC                 |
  +-----------------------------+    | ASSUMPTION 10.20.0.0/16          |
                                     | HA Cloud VPN                     |
                                     +----------------+-----------------+
                                                      |
                                                      v
                                     + - - - - - - - - - - - - - - - - +
                                       On-premises  ASSUMPTION
                                     | 10.0.0.0/12                    |
                                     | Java application               |
                                     |        |                       |
                                     |        v                       |
                                     | relational database            |
                                     | peak-hour latency is here      |
                                     + - - - - - - - - - - - - - - - - +
```

The load balancer, Apigee, and the VPN move packets. They do not make the on-premises database faster. Latency evidence is the trace across edge, Apigee, PSC, Cloud Run or VPN, Java, and the database.

## Response path

```text
  Cloud Run  or  on-prem Java
          |
          |  same connection, reverse direction
          v
  Internal ALB / Hub route / VPN
          |
          v
  api-psc-service-attachment
          |
          v
  Apigee endpoint attachment
          |
          v
  Apigee runtime
          |
          v
  Northbound PSC + regional external LB + Cloud Armor
          |
          v
  External client
```

On-premises return routing must know the customer prefixes that represent the API spoke, under the stated addressing assumptions. That route is fixed in the Hub and VPN, not by peering Apigee to another VPC.

## Constraints this path keeps

- Cloud Run ingress is `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`, so the default `run.app` URL is not a public bypass.
- The producer attachment accepts the Apigee tenant explicitly (`ACCEPT_MANUAL` plus an accept list).
- No organization range is assigned to the Apigee runtime. The only customer ranges on this path are the PSC NAT subnet, the private subnet, and the proxy-only subnet used by the regional load balancers.

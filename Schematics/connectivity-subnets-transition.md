# Private connectivity, special subnets, and the internal transition

Three challenge questions, each as its own text schematic. Names match the Terraform in `platform/GCP/terraform/modules/infrastructure/` and `modules/apigee/`.


## 1. Private connectivity artifacts

Challenge question: **Qué artefactos de conectividad privada usas?**

```text
  NORTHBOUND (customer consumes Apigee)
  --------------------------------------
  Regional external ALB
          |
          v
  google_compute_region_network_endpoint_group
          apigee-northbound-psc-neg
          type PRIVATE_SERVICE_CONNECT
          |
          v
  Apigee instance service attachment
          (provider-published, from google_apigee_instance)


  SOUTHBOUND (Apigee consumes our backend)
  -----------------------------------------
  google_apigee_endpoint_attachment.cloud_run_backend
          |
          v
  google_compute_service_attachment.api_psc
          name api-psc-service-attachment
          |
          v
  Internal regional ALB
          api-ilb-forwarding-rule
          scheme INTERNAL_MANAGED
          |
          v
  google_compute_region_network_endpoint_group
          api-backend-run-neg
          (serverless NEG -> Cloud Run)
```

Two different service attachments. The northbound one belongs to the Apigee instance. The southbound one is `api-psc-service-attachment` in the API spoke. They are not interchangeable.

There is no customer-to-provider VPC peering, and no extra peering used to simulate transit.

## 2. Special subnets

Challenge question: **Qué subredes especiales se requieren?**

All three sit in `api-spoke-vpc` (`10.80.0.0/16`, `us-south1`). They do not overlap the assumed Hub `10.20.0.0/16` or the assumed on-premises `10.0.0.0/12`.

```text
  api-spoke-vpc  10.80.0.0/16
  |
  +-- api-private-us-south1       10.80.0.0/28
  |      regular subnet
  |      ILB forwarding and private backend addresses
  |
  +-- api-psc-nat-us-south1       10.80.0.16/29
  |      purpose = PRIVATE_SERVICE_CONNECT
  |      NAT for consumers of api-psc-service-attachment
  |      GCP minimum for this purpose is /29
  |
  +-- api-proxy-only-us-south1    10.80.0.64/26
         purpose = REGIONAL_MANAGED_PROXY
         role    = ACTIVE
         Envoy proxies for the regional external ALB
         and the regional internal ALB
         GCP minimum for this purpose is /26
```

| Subnet | CIDR | Why it exists |
|---|---|---|
| `api-proxy-only-us-south1` | `10.80.0.64/26` | Regional Application Load Balancers refuse to run without a proxy-only subnet. |
| `api-psc-nat-us-south1` | `10.80.0.16/29` | The southbound service attachment translates each consumer endpoint into this range. |
| `api-private-us-south1` | `10.80.0.0/28` | Addresses for the internal forwarding rule and private backend placement. |

None of these ranges is assigned to the Apigee runtime. A serverless VPC connector range `10.80.0.32/28` is reserved in the addressing plan for optional Cloud Run egress into the VPC. It is not one of the two purpose-restricted subnets the diagram asks for.

## 3. Where the path becomes the internal network

Challenge question: **Dónde está el punto de transición a la red interna?**

```text
  Provider tenant                         Customer network
  ------------------                      ---------------------------

  Apigee runtime
       |
       |  endpoint attachment
       |
       v
  =========================  TRANSITION  =========================
       api-psc-service-attachment
       inside api-spoke-vpc
       NAT 10.80.0.16/29
  ===============================================================
       |
       +----> internal ALB -> serverless NEG -> Cloud Run
       |
       +----> Hub VPC (existing) -> Cloud VPN -> on-premises
```

The transition is the PSC service attachment published in the API VPC. North of that line, the packet is still inside the provider tenant and the PSC connection. South of that line, the packet is in customer routing: Cloud Run on the internal load balancer, or the Hub and the VPN toward on-premises.

That is also the line that keeps the two prohibitions:

- Backends stay off the Internet, because nothing south of the attachment has a public frontend.
- Transitive peering is not required, because Apigee never joins the Hub or the spoke as a peered VPC.

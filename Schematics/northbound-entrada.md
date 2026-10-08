# Northbound — how traffic enters the managed runtime

Challenge question: **Cómo entra el tráfico al runtime administrado?** (`entrada ?`).

The external load balancer stays in the customer project. It hands the request to Apigee over Private Service Connect. Apigee is not a subnet of `api-spoke-vpc` and is not given an organization CIDR.

```text
  [ Cliente externo ]
          |
          |  HTTPS :443
          |  public DNS  api.example.com
          |  TLS terminates at the external load balancer
          v
  +---------------------------------------------------------------+
  | TRUST: Internet -> customer edge                              |
  |                                                               |
  |  Regional External Application Load Balancer                  |
  |  region us-south1 · scheme EXTERNAL_MANAGED                   |
  |  forwarding rule   apigee-northbound-fwd-rule                  |
  |  address           apigee-northbound-external-ip               |
  |  target HTTPS proxy + url map + managed certificate           |
  |           |                                                   |
  |           |  Cloud Armor policy  api-armor-policy             |
  |           |  (WAF, IP filtering, rate limit)                  |
  |           v                                                   |
  |  Backend service   apigee-northbound-backend                  |
  |           |                                                   |
  |           |  PSC NEG  apigee-northbound-psc-neg               |
  |           |  network endpoint type PRIVATE_SERVICE_CONNECT    |
  |           |  target = Apigee instance service attachment      |
  +-----------|---------------------------------------------------+
              |
              |  Google-managed PSC data plane
              |  proxy-only subnet for the regional Envoy proxies:
              |  api-proxy-only-us-south1   10.80.0.64/26
              |  purpose REGIONAL_MANAGED_PROXY
              v
  + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
    TRUST: customer edge -> provider tenant
  | Tenant del proveedor                                         |
  | Apigee instance service attachment                           |
  | consumer_accept_list = the customer project that owns the NEG|
  |                                                              |
  | Runtime administrado                                         |
  | non-VPC-peering · runtime_type CLOUD                         |
  | no authorized_network · no /22 or /28 from the organization  |
  + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
              |
              v
       API proxy policies
       (authentication and authorization happen here,
        before any backend is called)
```

## Hop table

| Hop | Boundary | Protocol | Control |
|---|---|---|---|
| Client to LB | Internet to customer edge | HTTPS 443 | DNS, TLS certificate, Cloud Armor |
| LB to PSC NEG | Customer edge, still in-project | LB data plane | Backend service `apigee-northbound-backend` |
| NEG to Apigee | Customer project to provider tenant | Private Service Connect | Apigee instance service attachment and its accept list |

The response uses the same LB and PSC connection back to the client. Cloud Run is not on this path until Apigee accepts the call and starts the southbound target request.

## Reading notes

- `10.80.0.64/26` is the Envoy proxy-only range for the regional external load balancer. It is not an address assigned to Apigee.
- The northbound service attachment URI comes from the Apigee instance, after the organization and instance exist. It is not `api-psc-service-attachment`. That attachment is the southbound producer.

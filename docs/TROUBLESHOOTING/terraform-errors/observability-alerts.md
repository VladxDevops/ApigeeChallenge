# Observability AlertPolicy apply failures: invalid metric/resource descriptors

## Symptom

Applying the observability module fails with errors like:

```
Error: Error creating AlertPolicy: googleapi: Error 400: Field alert_policy.conditions[0].condition_threshold.filter had an invalid value of "resource.type = "http_load_balancer" AND metric.type = "loadbalancing.googleapis.com/https/backend_latencies"": The resource name does not represent a known descriptor.

Error: Error creating AlertPolicy: googleapi: Error 400: Field alert_policy.conditions[0].condition_threshold.filter had an invalid value of "resource.type = "http_load_balancer" AND metric.type = "loadbalancing.googleapis.com/https/request_count" AND metric.labels.response_code_class = "500"": The resource name does not represent a known descriptor.

Error: Error creating AlertPolicy: googleapi: Error 404: Cannot find metric(s) that match type = "vpn.googleapis.com/network/tunnel_established". If a metric was created recently, it could take up to 10 minutes to become available. Please try again soon.
```

## Root cause

- Cloud Monitoring validates metric types and monitored-resource descriptors at API time. If a referenced `resource.type` or `metric.type` is not recognized in the project, the AlertPolicy creation will fail at `terraform apply` (even though `terraform plan` succeeds).
- Some metric/resource descriptor combinations used in `platform/GCP/terraform/modules/observability` are not valid in the target project or the metric descriptor is not yet available.

## Recommended fixes

1. Remove `resource.type` predicates from failing load-balancer alert filters; use `metric.type` only, for example:

   - Replace `resource.type = "http_load_balancer" AND metric.type = "loadbalancing.googleapis.com/https/backend_latencies"`
   - With `metric.type = "loadbalancing.googleapis.com/https/backend_latencies"`

   Apply the same change for `request_count` alerts and matching dashboard filters.

2. For VPN alerts that return 404, verify the correct metric name for your Cloud VPN variant. If you cannot immediately confirm the metric name, comment out or gate the VPN AlertPolicy until the VPN resource exists and its metrics show up in Monitoring.

3. Introduce a defensive feature flag (e.g., `create_alerts_when_metrics_ready`) to gate AlertPolicy creation so you can apply infrastructure first, wait for metrics to register, then enable alert creation.

## Quick verification commands

- List metric descriptors:

```bash
gcloud monitoring metrics descriptors list --project=YOUR_PROJECT_ID | grep loadbalancing -C2
```

- Inspect time series for a metric:

```bash
gcloud monitoring time-series list --project=YOUR_PROJECT_ID --filter='metric.type="loadbalancing.googleapis.com/https/backend_latencies"' --limit=5
```

---

If you want, I can patch `platform/GCP/terraform/modules/observability/alerts.tf` and `dashboards.tf` to remove the `resource.type` predicates and add a gating variable. Say "patch now" and I'll prepare the code changes.
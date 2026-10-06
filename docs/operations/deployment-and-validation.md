# Deployment and Validation

This document defines the planned deployment workflow and the evidence to collect for the technical defense.

## Preconditions

- Google Cloud project exists.
- Billing is enabled.
- Terraform deployer identity exists.
- Remote state bucket is bootstrapped or can be created by an approved bootstrap run.
- Apigee entitlement and organization type are confirmed.
- Real CIDR inventory is reviewed for overlap.
- `us-south1` quotas are available.

## Terraform Workflow

From `platform/GCP/terraform`:

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -var-file=environments/DEV/dev.tfvars
```

Do not run `terraform apply` against an unknown or shared environment without explicit approval.

## Deployment Sequence

1. Bootstrap remote state.
2. Enable required Google APIs.
3. Grant deployment IAM to the Terraform service account.
4. Create the API spoke VPC and required subnets.
5. Create Cloud Armor policy and regional external Application Load Balancer.
6. Provision Apigee with non-VPC-peering networking.
7. Connect northbound PSC from the LB path to Apigee.
8. Deploy the Cloud Run backend with restricted ingress.
9. Publish private backend access through a PSC service attachment.
10. Create the Apigee endpoint attachment for southbound PSC.
11. Configure the Apigee API proxy target.
12. Validate Cloud Run and on-premises request paths.

## Validation Evidence

| Area | Evidence |
|---|---|
| Terraform formatting | `terraform fmt -recursive -check` exits 0. |
| Terraform syntax | `terraform validate` exits 0. |
| Plan review | Plan contains expected VPC, subnet, IAM, LB, PSC, Apigee, and backend resources only. |
| No direct backend exposure | Direct Cloud Run URL returns blocked/forbidden; only LB/Apigee path works. |
| Northbound path | Request to public API domain reaches Apigee proxy. |
| Southbound Cloud Run path | Apigee proxy receives successful response from Cloud Run target through PSC. |
| Southbound on-prem path | Test endpoint confirms reachability through Hub/VPN. |
| WAF | Cloud Armor logs show allowed and denied sample requests. |
| Observability | Logs/traces correlate request IDs across LB, Apigee, backend, and VPN where available. |

## Operational Checks

- Confirm no service-account keys are committed.
- Confirm `docs/internal/` is ignored by Git.
- Confirm Terraform state files are ignored and not part of the submission.
- Confirm Apigee runtime is drawn outside the customer VPC in the final diagram.
- Confirm the diagram shows trust boundaries and traffic direction.
- Confirm the Terraform remote state bucket uses uniform bucket-level access (`uniform_bucket_level_access = true`) per the Google Cloud guidance, and that object ACLs are not relied on for access management.
- Confirm the state bucket remains private and versioned, with `public_access_prevention = "enforced"` and no accidental public exposure.


## Rollback Strategy

Before apply, review resource dependencies and identify resources with customer traffic impact:

- DNS records and certificates.
- Load balancer forwarding rules.
- Apigee proxy deployments.
- PSC service attachments and endpoint attachments.
- Cloud Run revisions.

For Cloud Run, prefer revision rollback. For Apigee proxies, deploy a known-good revision. For networking changes, use Terraform plan review and avoid replacing shared resources unless explicitly approved.


### Apigee proxy bundle import workflow

For every proxy bundle under `APPS/APIgee/proxies/`, the XML files are the source of truth and the zip is a generated artifact used only for import.

- Canonical smoke-test bundle: `APPS/APIgee/proxies/hello-world-proxy/apiproxy`
- Experimental or alternate bundle: `APPS/APIgee/proxies/hello-cloudrun/apiproxy` (treat as non-canonical unless deliberately adopted)
- Do not upload a zip before the bundle has been validated and reviewed
- Generate the zip only immediately before the import step
- Upload the zip only to the intended Apigee org/environment after validation passes

Generate the zip:

```bash
cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies/hello-world-proxy
zip -r ../hello-world-proxy.zip apiproxy
```

Then import/deploy via the Apigee management API or the repo’s standard toolchain. Do not treat the zip as source; treat it as the final bundle artifact for deployment.

### Apigee bundle validation and review gate

"Do not upload a zip before the bundle has been validated and reviewed" means the bundle must pass a checklist before it is packaged and imported. This is a release gate, not a formatting preference.

A bundle is considered "validated and reviewed" only when all of the following are true:

1. XML syntax is valid.
   - Run `xmllint --noout` against the bundle XML files.
   - Confirm the manifest file name and the `name="..."` attribute match the proxy folder name.
   - Confirm there are no malformed XML nodes or partial edits.

2. The bundle matches repo conventions.
   - The source lives under `APPS/APIgee/proxies/<proxy-name>/apiproxy/`.
   - The archive root is `apiproxy/`, not the contents flattened at the zip root.
   - The selected bundle is the intended canonical one; alternate bundles such as `hello-cloudrun` are explicitly treated as non-canonical unless intentionally adopted.

3. Traffic contract is correct.
   - `ProxyEndpoint` `BasePath` is correct for the target envgroup hostname and intended API path.
   - `TargetEndpoint` `URL` does not contain placeholders, dummy values, or obviously wrong hostnames.
   - Southbound target URLs use `http://` when they connect to the internal PSC/ILB path, matching the repo networking design.
   - The target host is not hardcoded if the environment-specific endpoint must come from Terraform output.

4. The change is reviewed for risk.
   - Confirm the new or modified proxy does not bypass required networking/security controls.
   - Confirm the target backend is the intended one and the route path matches the architecture.
   - Confirm the change does not introduce a duplicate, conflicting, or stale proxy definition.
   - If the change affects API exposure, backend reachability, or security posture, record it in `changelog.md` and any affected architecture/security docs.

5. The bundle is ready for import.
   - The XML is stable.
   - The bundle is the correct version to deploy.
   - The zip is generated immediately before upload.
   - The upload target is the intended Apigee org/environment.

Typical validation commands:

```bash
cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies/hello-world-proxy
xmllint --noout apiproxy/hello-world-proxy.xml apiproxy/proxies/default.xml apiproxy/targets/default.xml
```

```bash
cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies/hello-world-proxy
zip -r ../hello-world-proxy.zip apiproxy
```

A bundle is not ready for upload if any of the above checks are missing, unverified, or unresolved. The review step is the explicit decision that "this bundle is safe to import" before the zip is sent to Apigee.

Quick checklist before upload:

- [ ] XML is well-formed and the manifest name matches the proxy folder name.
- [ ] Bundle is under `APPS/APIgee/proxies/<proxy-name>/apiproxy/` and uses `apiproxy/` as the zip root.
- [ ] `BasePath` matches the intended envgroup hostname and API path.
- [ ] `TargetEndpoint` URL is valid, not a placeholder, and uses the correct internal scheme/port.
- [ ] The selected bundle is the canonical one for this repo; stale or alternate bundles are not being imported by mistake.
- [ ] The change has been reviewed for networking/security impact and recorded in `changelog.md` if needed.
- [ ] The zip is generated immediately before upload, and uploaded only to the intended Apigee org/environment.

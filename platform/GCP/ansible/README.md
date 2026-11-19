# Ansible: Apigee proxy deploy and path verification

Ansible does **not** manage Cloud Run, networking, IAM or any other Terraform-owned
resource. It only (a) validates, builds, imports and deploys the Apigee proxy bundle and
(b) verifies the end-to-end path. Everything runs on this machine against Google APIs.

## Prerequisites

- `ansible-core` (tested design: 2.16), no extra collections needed
- `gcloud` (logged in: `gcloud auth list`), `curl` >= 7.76, `zip`, `terraform`
- The DEV Terraform root configured and its outputs available

## Configure

Terraform remains the source of truth. Before the playbooks run, configure and apply the DEV Terraform root; Ansible reads these outputs:

| Terraform output | Ansible value |
|---|---|
| `compute_project_id` | `compute_project_id`, `apigee_org` |
| `apigee_service_account_email` | `apigee_service_account_email` |
| `apigee_endpoint_attachment_host` | `apigee_endpoint_attachment_host` |
| `northbound_ip` | `northbound_ip` fallback |

Environment-local non-Terraform values can be set in `inventory/group_vars/dev.yml`:

| Variable | Meaning |
|---|---|
| `envgroup_hostname` | Hostname attached to the Apigee environment group |
| `northbound_ip` | Optional reserved IP override; empty = read Terraform output |
| `curl_insecure` | Dev-only northbound test option |
| `cloud_run_service_name` | Cloud Run service whose request logs are checked |

Shared values (paths, proxy name, base path, retries) are in `inventory/group_vars/all.yml`. Do not copy a live endpoint host, project ID, or service-account email into committed files.

## Run (always from this directory)

```bash
cd platform/GCP/ansible
ansible-playbook playbooks/verify-path.yml --syntax-check
ansible-playbook playbooks/deploy-proxy.yml --syntax-check

# Read-only: safe any time
ansible-playbook playbooks/verify-path.yml

# Changes Apigee: needs explicit environment confirmation
APIGEE_DEPLOY_ENV=dev ansible-playbook playbooks/deploy-proxy.yml
```

Placeholders or unresolved Terraform outputs stop the run with a clear fix message.

## What the playbooks do

`verify-path.yml` (read-only)
1. Resolves Terraform-owned values and validates the bundle sources.
2. Checks the endpoint attachment is `ACTIVE` and `ACCEPTED`.
3. Checks deployment state, exact service account, instance and route.
4. Calls `https://<envgroup_hostname>/hello` through the northbound IP and expects HTTP 200.
5. Looks for the request in Cloud Run logs (warning only if absent).

`deploy-proxy.yml`
1. Resolves Terraform values and requires explicit environment confirmation.
2. Validates the bundle, builds the zip, imports it, and reads the revision.
3. Deploys the exact revision with `serviceAccount=` and `override=true`.
4. Waits until `READY`, then verifies exactly that revision.

## Bundle rules enforced before import

- Required files exist and are well-formed XML.
- Proxy name matches `apigee_proxy_name`; base path is `/hello`.
- Target URL is exactly `https://<Terraform endpoint host>/hello`.
- `GoogleIDToken` authentication requires `<SSLInfo><Enabled>true</Enabled>`.
- `IgnoreValidationErrors=true` is accepted only in `dev`.
- `<Audience>` is a bare HTTPS origin with no path or trailing slash.

## Safety notes

- The access token is never printed; it is passed to curl on stdin and tasks that handle it use `no_log`.
- The old zip is deleted before each build; `zip -r` alone would preserve stale entries.
- The zip under `APPS/APIgee/proxies/` is generated and ignored by Git.
- Nothing here edits Terraform, Cloud Run ingress/IAM, or load balancers.

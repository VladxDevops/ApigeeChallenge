# Ansible: Apigee proxy deploy and path verification

Phase 1. Ansible does **not** manage Cloud Run, networking, IAM or any other Terraform-owned
resource. It only (a) validates, builds, imports and deploys the Apigee proxy bundle and
(b) verifies the end-to-end path. Everything runs on this machine against Google APIs.

Place this folder at `platform/GCP/ansible/`.

## Prerequisites

- `ansible-core` (tested design: 2.16), no extra collections needed (built-in modules only)
- `gcloud` (logged in: `gcloud auth list`), `curl` >= 7.76, `zip`
- `terraform` only if `northbound_ip` is left empty (it is then read from `terraform output -raw northbound_ip`)

## Configure

Edit `inventory/group_vars/dev.yml` and replace every `PLACEHOLDER` (or pass `-e key=value`):

| Variable | Meaning |
|---|---|
| `compute_project_id` | GCP project id |
| `apigee_org` | Apigee org id (defaults to `compute_project_id`) |
| `apigee_service_account_email` | Service account the deployment runs as |
| `apigee_endpoint_attachment_host` | Southbound host; must equal the host in `targets/default.xml` |
| `northbound_ip` | Reserved regional IP; empty = read the Terraform output |
| `envgroup_hostname` | `api.example.com` |

Shared values (paths, proxy name, base path, retries) are in `inventory/group_vars/all.yml`.

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

Placeholders left in place, a missing tool, or a missing gcloud login stop the run immediately
with a message saying what to fix.

## What the playbooks do

`verify-path.yml` (read-only)
1. Validates the bundle sources (see rules below).
2. Endpoint attachment with the expected host is `ACTIVE` and `ACCEPTED`.
3. Deployment is `READY`, runs as the expected service account, on the expected instance, route `/hello` in the expected envgroup.
4. Calls `https://<envgroup_hostname>/hello` through the northbound IP (`--resolve`) and expects HTTP 200.
5. Looks for the request in Cloud Run logs (warning only if absent).

`deploy-proxy.yml`
1. Deploy guard: refuses `--check`, and requires `APIGEE_DEPLOY_ENV` to equal the target environment.
2. Validates the bundle, builds the zip, imports it (the new revision number is read from the response).
3. Deploys that revision with the REST call using `serviceAccount=` and `override=true`.
4. Waits until `READY`, then runs the same verification for exactly that revision.

## Bundle rules enforced before import

- Exactly the expected files exist and are well-formed XML.
- Proxy name matches `apigee_proxy_name`; base path is `/hello`.
- Target URL is `https://` and its host equals `apigee_endpoint_attachment_host`.
- `GoogleIDToken` authentication requires `<SSLInfo><Enabled>true</Enabled>`.
- `IgnoreValidationErrors=true` is accepted only for environments in `tls_validation_bypass_allowed_envs` (dev).
- `<Audience>` is a bare https origin (no path, no trailing slash). It is checked, never rewritten.

## Safety notes

- The access token is never printed; it is passed to curl on stdin and tasks that touch it use `no_log`.
- The old zip is deleted before each build. `zip -r` alone only adds files, so removed files would otherwise stay in the bundle.
- The zip at `APPS/APIgee/proxies/hello-world-proxy.zip` is a generated file and is rewritten on every deploy.
  Consider git-ignoring it, or point `proxy_zip_path` elsewhere.
- Nothing here edits Terraform, Cloud Run ingress/IAM, or the load balancer.

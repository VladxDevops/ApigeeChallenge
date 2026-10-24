# Apigee southbound troubleshooting: 404 → 403 → 500 → 503 → 200

Runbook for the `hello-world-proxy` failure chain on the Apigee Challenge project. It records what was observed, what was tried, what failed, what fixed each problem, and how to recognize each error faster next time.

- **Date of session:** 2026-10-23 / 2026-10-24
- **Environment:** `dev`, region `us-south1`, Apigee org `apigeechallenge`
- **Final result:** `curl https://api.example.com/hello` returns HTTP 200 (`"Hello from Cloud Run backend!"`) with Cloud Run protected by IAM (no `allUsers`).
- **Placeholders used below:** `SA_EMAIL` = the Apigee service account email (value built from `apigee_admin_service_account_name_dev` in `dev.tfvars`), `REV` = proxy revision number, `HOST` = endpoint attachment host.

> Not everything here was verified directly. Items marked **(unverified)** are the most likely explanation but were not isolated by a test.

---

## 1. Architecture (what the request travels through)

```text
curl (client)
  -> northbound external ALB (443, regional, Cloud Armor)          34.0.154.130
  -> PSC NEG -> Apigee service attachment (Apigee runtime, dev env)
  -> Apigee proxy "hello-world-proxy"  (target: https://HOST/hello)
  -> Apigee endpoint attachment "cloudrun-backend"                  host 10.0.148.2
  -> PSC service attachment "api-psc-service-attachment"
  -> internal Application LB (INTERNAL_MANAGED, HTTPS 443)
  -> serverless NEG
  -> Cloud Run "hello-container-backend"
       ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER
       IAM     = roles/run.invoker for the Apigee service account (no allUsers)
```

Key facts that caused most of the confusion:

- `34.0.154.130` is the **northbound** ALB. It sends traffic *to* Apigee. It is never a valid proxy target.
- `10.0.148.2` is the **Apigee endpoint attachment host**, the private address Apigee uses to reach the southbound path. It is not the ILB's own IP.
- The Cloud Run `run.app` URL is public DNS, but with the ingress above it only accepts traffic that arrives through the internal load balancer.

---

## 2. Timeline at a glance

| # | Symptom | Where it came from | Root cause | Fix |
|---|---|---|---|---|
| 1 | `HTTP/2 404`, HTML body "The requested URL `/` was not found" | Cloud Run / Google front end, not Apigee | Target was the public `run.app` URL; base path stripped so backend saw `/` | Route through endpoint attachment; set target path |
| 2 | `HTTP/2 404`, HTML body "The requested URL `/hello` was not found" | Same | Path now correct, but `run.app` URL is blocked by Cloud Run ingress | Same (use the private path) |
| 3 | Cloud Run logs: `GET 403 http://10.0.148.2/hello` | Cloud Run IAM | Request arrived through the private path but the caller was unauthenticated | Use ID-token auth instead of `allUsers` |
| 4 | Import error 400: "The URL must be ssl enabled if Authentication is present" | Apigee bundle validation | `GoogleIDToken` auth on an `http://` target | HTTPS listener on the ILB, `https://` target |
| 5 | `gcloud apigee apis deploy` → `MISSING_SERVICE_ACCOUNT` | Apigee deploy validation | Proxy with `GoogleIDToken` must be deployed with a service account | Deploy with `serviceAccount=` via REST |
| 6 | Deploy REST call → 403 `PERMISSION_DENIED` | Apigee / IAM | Caller lacked permission to attach the service account | Grant `roles/iam.serviceAccountUser` on the SA |
| 7 | `500 GoogleTokenGenerationFailure` | Apigee runtime | Apigee could not mint a token for the SA | Grant `roles/iam.serviceAccountTokenCreator` |
| 8 | `503 SslHandshakeFailed: No subject alternative names present` | Apigee runtime → ILB | Self-signed ILB certificate had no SAN | Add the endpoint attachment IP as an `ip_addresses` SAN |
| 9 | `200 OK` | — | — | Working |

Mislabel worth remembering: the original report said "400 error", but the output was a **404**. Always read the actual status line first.

---

## 3. Detailed findings

### 3.1 HTTP 404 with an HTML body (Google-style, not Apigee JSON)

**What it looked like**

```text
< HTTP/2 404
< content-type: text/html; charset=UTF-8
< via: 1.1 google
<h1>Error: Not Found</h1>
<h2>The requested URL <code>/</code> was not found on this server.</h2>
```

**How to tell where a 404 comes from**

| Body | Source |
|---|---|
| JSON with `fault.detail.errorcode` such as `messaging.adaptors.http.flow.ApplicationNotFound` | Apigee (no proxy matched: wrong environment group host, base path, or no deployment) |
| HTML `Error: Not Found` page | Google front end in front of Cloud Run, or the Cloud Run ingress blocking the call |
| Your app's own JSON | Your backend (not applicable here, the app answers 200 on every path except `/health` and `/readiness`, which it also answers 200) |

**What was tried**

1. Looked at `targets/default.xml`: target was `https://hello-container-backend-274925551228.us-south1.run.app` with no path. Apigee strips the proxy base path (`/hello`) and appends only the remainder, so the backend saw `GET /`. That explains the `/` in the first error body.
2. Changed the target URL to `.../run.app/hello`. The error body then said `/hello` was not found. The path was right and the 404 persisted.

**Root cause (likely, not directly isolated) (unverified)**
The target was the public `run.app` URL. The Cloud Run service uses ingress `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`, so calls from Apigee over that URL do not count as coming from the internal load balancer, and Cloud Run answers with a plain HTML 404. Evidence: the backend's own request log showed **no** line for those requests, so they never reached the container.

**What did not help**
- Adding `/hello` to the target URL (necessary for later, but not the fix).
- Granting more IAM on Cloud Run (not the layer failing at this stage).

**Fix**
Point the target at the endpoint attachment host, not at `run.app`.

---

### 3.2 Finding the private path and the 403 in the Cloud Run logs

**Commands**

```bash
gcloud run services logs read hello-container-backend \
  --region=us-south1 --project=apigeechallenge --limit=50
```

**Observed**

```text
GET 403 http://10.0.148.2/
GET 403 http://10.0.148.2/hello
```

**What this proves**
- A request addressed to `10.0.148.2` (the endpoint attachment host) reached Cloud Run. The whole private path (Apigee → endpoint attachment → PSC → ILB → NEG) was already working.
- The 403 comes from Cloud Run IAM, because no invoker identity accompanied the call. The container never ran, which is why the app did not log its own request line.

**Rule of thumb:** a 403 in Cloud Run logs with host `10.0.148.2` means **network OK, auth missing**. A request that never appears in the logs means **it was blocked before the container** (ingress or load balancer).

---

### 3.3 The `allUsers` decision

`roles/run.invoker` for `allUsers` would have fixed the 403 immediately, but it was rejected as a design decision.

- A serverless NEG behind an ILB forwards the `Authorization` header. Cloud Run validates a Google ID token in it.
- Granting `run.invoker` to the Cloud Run **runtime** service account does **not** help. That account is the container's identity, not the caller's.
- The chosen design: Apigee attaches a Google ID token (target `<Authentication><GoogleIDToken>`), and only the Apigee service account has `run.invoker`.
- A setting that disables the invoker IAM check on Cloud Run exists. It was not used, because the effect is similar to `allUsers`.

---

### 3.4 Import error: "The URL must be ssl enabled if Authentication is present"

**Command that failed**

```bash
curl -X POST "https://apigee.googleapis.com/v1/organizations/$ORG/apis?action=import&name=$PROXY_NAME" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -F "file=@hello-world-proxy.zip"
```

**Error:** `bundle contains errors` / `apiproxy/targets/default.xml: The URL must be ssl enabled if Authentication is present.`

**Cause:** the target was `http://10.0.148.2/hello` while `<Authentication>` was present.

**Fix:** the southbound ILB had to speak HTTPS. See section 4.

---

### 3.5 `MISSING_SERVICE_ACCOUNT` on `gcloud apigee apis deploy`

**Command**

```bash
gcloud apigee apis deploy 8 --api=hello-world-proxy --environment=dev \
  --organization=apigeechallenge --override
```

**Error:** `MISSING_SERVICE_ACCOUNT: Deployment ... requires a service account identity, but one was not provided with the request.`

**Cause:** a proxy that uses `GoogleIDToken` cannot be deployed without a service account.

**What worked:** the REST API with `serviceAccount=`:

```bash
ORG=apigeechallenge
REV=8
SA="SA_EMAIL"
curl -s -X POST \
  "https://apigee.googleapis.com/v1/organizations/$ORG/environments/dev/apis/hello-world-proxy/revisions/$REV/deployments?override=true&serviceAccount=$SA" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"
```

**What was not confirmed:** whether the installed `gcloud` has a `--service-account` flag on `apis deploy`. It was never confirmed. Check with:

```bash
gcloud apigee apis deploy --help | grep -i service
```

**Impersonation note:** `--impersonate-service-account` changes who *performs* the API call. It does **not** set the identity the proxy uses at runtime. Only the deployment's `serviceAccount` does that.

**Important operational rule:** `gcloud apigee apis import` creates a new revision each time. Use the revision number from the import response when deploying. Deploying with the plain `gcloud` command (no service account) will keep failing for this proxy. Use the REST call instead.

---

### 3.6 403 `PERMISSION_DENIED` on the REST deploy call

**Cause:** attaching a service account to a deployment requires the caller to hold `iam.serviceAccounts.actAs` on it.

**Fix**

```bash
gcloud iam service-accounts add-iam-policy-binding SA_EMAIL \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/iam.serviceAccountUser"
```

Wait a minute or two for propagation. An earlier attempt had also been run with a leftover placeholder email in `$SA`. Print the variable (`echo $SA`) before calling the API.

---

### 3.7 `500 GoogleTokenGenerationFailure`

**Response**

```json
{"fault":{"faultstring":"Google token generation has failed. ...",
"detail":{"errorcode":"messaging.adaptors.http.filter.GoogleTokenGenerationFailure"}}}
```

**Meaning:** the proxy was running, matched, and reached the target step, but Apigee could not mint an ID token for the deployment's service account.

**Fix:** grant `roles/iam.serviceAccountTokenCreator` on the service account so Apigee can mint tokens. In the session this was added on both Apigee service accounts, and the error moved on to the next one. The exact principal that strictly needs it was not isolated. The Apigee service agent (`service-PROJECT_NUMBER@gcp-sa-apigee.iam.gserviceaccount.com`) is the standard candidate. Narrow this later (see section 7).

```bash
PROJECT_NUMBER=$(gcloud projects describe apigeechallenge --format='value(projectNumber)')
gcloud iam service-accounts add-iam-policy-binding SA_EMAIL \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-apigee.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

No redeploy needed, it is an IAM change.

---

### 3.8 `503 SslHandshakeFailed: No subject alternative names present`

**Response**

```json
{"fault":{"faultstring":"SSL Handshake failed java.security.cert.CertificateException: No subject alternative names present",
"detail":{"errorcode":"messaging.adaptors.http.flow.SslHandshakeFailed"}}}
```

**Cause:** the self-signed ILB certificate had a common name only (`api-ilb.internal`). Java TLS clients require a SAN and Apigee connects to the IP `10.0.148.2`.

**Fix:** add the endpoint attachment IP to the certificate's SAN list. That removes the SAN error without relying on disabling validation:

```hcl
resource "tls_self_signed_cert" "ilb_self_signed" {
  private_key_pem       = tls_private_key.ilb_self_signed.private_key_pem
  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]

  dns_names    = ["api-ilb.internal"]
  ip_addresses = [var.apigee_endpoint_attachment_host]

  subject {
    common_name  = "api-ilb.internal"
    organization = "Rocket Code Demo"
  }
}
```

`apigee_endpoint_attachment_host` is a variable (value in `dev.tfvars`: the endpoint attachment `host`, `10.0.148.2`). It is a variable and not a resource reference, because referencing the endpoint attachment from the certificate would create a dependency cycle (endpoint attachment → service attachment → ILB → certificate).

**Not isolated (unverified):** whether `IgnoreValidationErrors=true` alone would have bypassed the SAN error. The proxy already had it set in `SSLInfo` when the error appeared, or the setting may not have been in the deployed revision. Check both `default.xml` and the deployed revision before trusting that flag.

---

## 4. Final working configuration

### 4.1 Terraform (`modules/infrastructure/networking.tf`), new resources

```text
tls_private_key.ilb_self_signed
tls_self_signed_cert.ilb_self_signed          (with dns_names + ip_addresses SAN)
google_compute_region_ssl_certificate.api_ilb (name_prefix, create_before_destroy)
google_compute_region_target_https_proxy.api_proxy_https
google_compute_forwarding_rule.api_ilb_https  (INTERNAL_MANAGED, port 443)
```

- `google_compute_service_attachment.api_psc.target_service` now points at `google_compute_forwarding_rule.api_ilb_https.id`.
- New variable `apigee_endpoint_attachment_host` declared in the module `variables.tf`, root `variables.tf`, and passed from `infrastructure.tf`. Value set in `dev.tfvars`.
- The old port-80 forwarding rule and HTTP proxy are still in the code and are no longer reachable through PSC. Remove them in a later planned change.

### 4.2 Proxy target (`apiproxy/targets/default.xml`)

```xml
<HTTPTargetConnection>
  <Authentication>
    <GoogleIDToken>
      <Audience>https://hello-container-backend-274925551228.us-south1.run.app</Audience>
    </GoogleIDToken>
  </Authentication>
  <SSLInfo>
    <Enabled>true</Enabled>
    <IgnoreValidationErrors>true</IgnoreValidationErrors>
  </SSLInfo>
  <URL>https://10.0.148.2/hello</URL>
  <Properties>
    <Property name="success.codes">1xx,2xx,3xx</Property>
  </Properties>
</HTTPTargetConnection>
```

- The audience is the **Cloud Run service URL**, even though traffic goes through the ILB.
- `IgnoreValidationErrors=true` is dev-only (self-signed cert, IP host).

### 4.3 IAM that must exist

| Grant | Principal | On | Why |
|---|---|---|---|
| `roles/run.invoker` | Apigee service account | Cloud Run service (project-level in the current Terraform) | Cloud Run accepts the ID token |
| `roles/iam.serviceAccountUser` | the human deploying | Apigee service account | Attach the SA to the deployment |
| `roles/iam.serviceAccountTokenCreator` | Apigee service agent (and the SA, as was done) | Apigee service account | Apigee mints the ID token |

All of these were granted manually during the session. They should be moved into Terraform (see section 7).

### 4.4 Deploy sequence for a new proxy revision

```bash
# 1. Import (creates a new revision, note its number in the response)
curl -X POST "https://apigee.googleapis.com/v1/organizations/$ORG/apis?action=import&name=hello-world-proxy" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -F "file=@hello-world-proxy.zip"

# 2. Deploy with the service account (REST, not plain gcloud)
curl -s -X POST \
  "https://apigee.googleapis.com/v1/organizations/$ORG/environments/dev/apis/hello-world-proxy/revisions/$REV/deployments?override=true&serviceAccount=$SA" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)"

# 3. Read back: expect state READY and serviceAccount set
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://apigee.googleapis.com/v1/organizations/$ORG/environments/dev/apis/hello-world-proxy/revisions/$REV/deployments"

# 4. Test
curl -vk --resolve api.example.com:443:34.0.154.130 https://api.example.com/hello
```

---

## 5. Diagnostic cheat sheet (use this first next time)

### 5.1 Decision tree by symptom

```text
Status/body                                                 Look at
----------------------------------------------------------  ------------------------------------------------
404, HTML "Error: Not Found"                                Cloud Run ingress / target URL host (use HOST, not run.app)
404, JSON ApplicationNotFound                               Env group hostname, base path, proxy not deployed
403 in Cloud Run logs, host 10.0.148.2                      Invoker IAM / ID token missing or rejected
500 GoogleTokenGenerationFailure                            serviceAccount on deployment; serviceAccountTokenCreator; audience
503 SslHandshakeFailed (no SAN / trust)                     ILB certificate SAN; SSLInfo; endpoint attachment host
503 / timeout, no TLS message                               ILB forwarding rule, proxy-only subnet, firewall on 443
Import 400 "ssl enabled if Authentication"                  Use https:// target
MISSING_SERVICE_ACCOUNT                                     Deploy with serviceAccount= (REST)
Deploy 403 PERMISSION_DENIED                                serviceAccountUser for the caller
```

### 5.2 Commands

```bash
# What am I logged in as?
gcloud config get-value account

# Endpoint attachment: host, state, connectionState
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://apigee.googleapis.com/v1/organizations/apigeechallenge/endpointAttachments"
# Expect: state ACTIVE, connectionState ACCEPTED, host = the IP used in the target URL.
# NOTE: `gcloud apigee endpoint-attachments` does NOT exist in the installed gcloud, use REST.
# NOTE: the `name` field already contains the full path; append only the short name.

# Service attachment connections and accept list
gcloud compute service-attachments describe api-psc-service-attachment \
  --region=us-south1 --format="yaml(connectedEndpoints,consumerAcceptLists)"

# Cloud Run IAM and recent requests
gcloud run services get-iam-policy hello-container-backend --region=us-south1 --project=apigeechallenge
gcloud run services logs read hello-container-backend --region=us-south1 --project=apigeechallenge --limit=50

# Proxy deployment state (state, serviceAccount)
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://apigee.googleapis.com/v1/organizations/apigeechallenge/environments/dev/apis/hello-world-proxy/revisions/$REV/deployments"

# Service account IAM
gcloud iam service-accounts get-iam-policy SA_EMAIL
```

### 5.3 Apigee debug (trace) session, REST

```bash
BASE="https://apigee.googleapis.com/v1/organizations/$ORG/environments/dev/apis/hello-world-proxy/revisions/$REV/debugsessions"
TOKEN=$(gcloud auth print-access-token)
curl -s -X POST "$BASE?timeout=600" -H "Authorization: Bearer $TOKEN"    # note the session id in "name"
# send the failing curl, then:
curl -s "$BASE/SESSION/data" -H "Authorization: Bearer $TOKEN"
curl -s "$BASE/SESSION/data/MESSAGE_ID" -H "Authorization: Bearer $TOKEN"
curl -s -X DELETE "$BASE/SESSION" -H "Authorization: Bearer $TOKEN"
```

In the console: Apigee → API proxies → hello-world-proxy → Debug → select `dev` and the revision → Start debug session. Look at the "Request sent to target" step (URL and path) and the target response status.

### 5.4 Quick sanity checks before deeper debugging

1. Is the deployed revision the one you just imported? Import creates a new revision every time.
2. Does the deployment show `state: READY` and the expected `serviceAccount`?
3. Is the target host the endpoint attachment `host` and not the `run.app` URL or the ALB's external IP?
4. Does the target URL include the `/hello` path (Apigee only appends the part after the base path)?
5. Does a request line appear in the Cloud Run logs? (No line = blocked before the container.)
6. Does a variable still hold a placeholder value (for example `SA`)? `echo` it.

---

## 6. Things that did not work, or were wrong in the process

| Attempt | Result | Lesson |
|---|---|---|
| Treating the first error as a 400 | It was a 404 | Read the status line before theorizing |
| `gcloud apigee endpoint-attachments describe ...` | `Invalid choice` | Not available in the installed gcloud, use the REST API |
| Describing the endpoint attachment with a doubled path | 404 from Google | `name` already contains `organizations/.../endpointAttachments/...` |
| Suspecting the service attachment accept list was rejecting Apigee | Wrong, connection was `ACCEPTED` | Check `connectionState` before guessing at the accept list |
| Target URL changes alone (`/` then `/hello`) on `run.app` | Still 404 | Right path, wrong network route |
| Adding `<Authentication>` to an `http://` target | Import rejected | Auth requires an `https://` target |
| `gcloud apigee apis deploy` after adding auth | `MISSING_SERVICE_ACCOUNT` | Use REST with `serviceAccount=` |
| REST deploy before granting `serviceAccountUser` | 403 | The deployer needs `actAs` on the SA |
| Adding the same `tls_self_signed_cert` block twice | `Duplicate resource` | Replace the block, do not paste a second one |
| Deleting a duplicate and removing `tls_private_key` too | `Reference to undeclared resource` | After edits run `terraform validate` before any apply |

---

## 7. Follow-up work and open risks

1. **Backend echoes request headers.** `src/index.js` returns `headers: req.headers`, so the response included the `authorization: Bearer ...` token, the caller's public IP, and internal addresses. Remove this from the response and rebuild the image. Do not paste full responses from this endpoint until it is fixed.
2. **Move manual IAM into Terraform.** `serviceAccountUser` (deployer), `serviceAccountTokenCreator` (Apigee service agent and service account), and a service-level `run.invoker`. The token-creator grant was added to both Apigee service accounts, which is broader than needed.
3. **Narrow roles.** The Apigee service account has `roles/apigee.admin` at project level, which is more than a runtime identity needs. Consider a dedicated, narrower runtime service account for the proxy and a service-scoped `run.invoker`.
4. **Self-signed certificate and `IgnoreValidationErrors` are dev-only.** For a stricter design: add the certificate to an Apigee truststore, or use a private CA, and set validation on.
5. **Remove the unused HTTP (port 80) forwarding rule and target proxy** in a separate change after reading `terraform plan` for replacements.
6. **Endpoint attachment host can change** if the endpoint attachment is replaced (for example after a service attachment replacement). If it does, update `apigee_endpoint_attachment_host` in `dev.tfvars` and the URL in `default.xml`, then re-apply and redeploy.
7. **Update documentation:** `Agents.md` (ILB is HTTPS on 443; access is by service account, not `allUsers`; the doc says `INGRESS_TRAFFIC_INTERNAL_ONLY` but the code uses `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`), `changelog.md`, `docs/networking/`, and `docs/architecture/traffic-flows.md` where they mention port 80.
8. **Verify before relying on:** whether `gcloud apigee apis deploy` supports a service account flag in your gcloud version, and exactly which principal needs `serviceAccountTokenCreator`.

---

## 8. One-paragraph summary for future-you

The proxy's path worked early (Cloud Run logs showed requests arriving from `10.0.148.2`) but was unauthenticated, and the public `run.app` URL was blocked by ingress. The fix was to keep Cloud Run internal-only, give the ILB an HTTPS listener with a self-signed certificate whose SAN includes the endpoint attachment IP, use `GoogleIDToken` authentication on an `https://` target, deploy the proxy with a service account via the REST API, and grant `serviceAccountUser`, `serviceAccountTokenCreator`, and `run.invoker` to the right principals. Read the status line and body source first (Apigee JSON vs Google HTML), check whether the request appears in Cloud Run logs, and work outward from there.

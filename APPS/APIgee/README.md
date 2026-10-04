+++
title = "APIgee Apps — API Proxy Bundles"
domain = "apigee"
tier = 3
topics = ["apigee", "api-proxy", "proxies", "hello-world-proxy"]
parent = "README.md"
children = []
related = [
    "Agents.md",
    "docs/architecture/traffic-flows.md",
    "docs/networking/network-architecture.md",
    "platform/GCP/terraform/modules/apigee/README.md",
    ".claude/skills/apigee-proxy-bundle/SKILL.md"
]
updated_by = "Claude"
version = "1.0"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Agent rules**: [`Agents.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/Agents.md)
> **Deployment workflow**: [`.claude/skills/apigee-proxy-bundle/SKILL.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/.claude/skills/apigee-proxy-bundle/SKILL.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Human-facing overview of the API proxy bundles in this repo — what they are, what's here today, and how to add one.
- Questions Answered: What is an Apigee proxy? What proxies exist right now? Do proxies need their own container? How do I test one end to end?
- When to Retrieve: Orienting on this directory, or explaining the proxy layer during the oral defense.
- When NOT to Retrieve: Terraform coding rules (use Agents.md instead), or the Apigee org/instance Terraform itself (use modules/apigee/README.md).
-->

# APIgee Apps

This directory holds the **API proxy bundles** deployed into the Apigee organization that `platform/GCP/terraform/modules/apigee/` provisions.

## What a proxy bundle actually is

An Apigee API proxy is **configuration, not compute**. It's a folder of XML files — no Dockerfile, no container image, no build step. Apigee's managed runtime reads the XML directly; "deploying" a proxy means zipping the folder and uploading it to the Apigee Management API, not building and pushing an image. If you're picturing a second Cloud Run service or container for the proxy, that's not how this works — see `Agents.md` for the detail.

## What's here

## Proxy bundle source of truth and zip workflow

The XML files under `proxies/<proxy-name>/apiproxy/` are the source of truth. The generated `.zip` file is an import artifact used only to upload the bundle into Apigee.

Use exactly one active bundle per proxy name. In this repo, the canonical smoke-test bundle is:

- `APPS/APIgee/proxies/hello-world-proxy/apiproxy`

The `hello-cloudrun` directory is a separate experimental or archived bundle and should not be treated as the active repo source of truth unless the team intentionally decides to keep both bundles as supported proxies.

Before creating the zip, do all of the following in order:

1. Confirm the correct bundle is selected.
   - Verify you are working in the intended proxy folder: `APPS/APIgee/proxies/hello-world-proxy/apiproxy`.
   - Make sure the proxy folder name matches the bundle name and the manifest name used in the XML.
   - Do not package an alternate or stale bundle by mistake.

2. Validate the XML.
   - Check that the XML files are well-formed and complete.
   - Confirm the `ProxyEndpoint` and `TargetEndpoint` definitions are present and valid.
   - Run a syntax check, for example:

   ```bash
   cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies/hello-world-proxy
   xmllint --noout apiproxy/hello-world-proxy.xml apiproxy/proxies/default.xml apiproxy/targets/default.xml
   ```

3. Verify the routing contract in a concrete, step-by-step way.
   - Open the bundle files and read the exact values you are about to deploy:

   ```bash
   cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies/hello-world-proxy
   sed -n '1,220p' apiproxy/proxies/default.xml
   sed -n '1,220p' apiproxy/targets/default.xml
   ```

   - Find the `BasePath` in the `ProxyEndpoint` config. This is the URL path segment that comes after the hostname. Example:

   ```xml
   <HTTPProxyConnection>
     <BasePath>/hello</BasePath>
   </HTTPProxyConnection>
   ```

   This means the public route is expected to look like:

   ```text
   https://<Apigee-hostname>/hello
   ```

   - Compare that against the repo’s expected architecture and hostname. In this project, you should read the relevant design docs before deciding the value is correct:

   ```text
   docs/architecture/traffic-flows.md
   docs/networking/network-architecture.md
   ```

   - Ask: “If a client calls the API through Apigee, what path should it hit?” If the answer is `/hello`, then the `BasePath` must match that exactly. If the app is supposed to be under `/api/v1`, it must be `/api/v1` — not `/hello`, not `/`, and not a random path.
   - If the repo or environment design says the external host is the Apigee envgroup hostname, then `BasePath` is not the full URL; it is only the path after the hostname.
   - The hostname itself comes from the Terraform variable `apigee_envgroup_hostnames` in `platform/GCP/terraform/environments/DEV/dev.tfvars`.
   - This value is intentionally a placeholder until a real DNS name and certificate are assigned. In the current dev configuration it is set to a sample hostname such as `api.example.com` because no custom domain is available yet.
   - Check that the `BasePath` is not a placeholder like `/REPLACE_ME`, `/test`, or a leftover value from another environment.

   - Next, inspect the target URL in the `TargetEndpoint`. Example:

   ```xml
   <HTTPTargetConnection>
     <URL>http://internal-backend:8080</URL>
   </HTTPTargetConnection>
   ```

   - This is the service the proxy calls after it accepts the request.
   - Confirm the target is an internal service, PSC address, ILB hostname, or repo-approved private endpoint — not a public internet hostname and not a hardcoded test value.
   - Look for obvious placeholders or stale values, such as:
     - `localhost`
     - `0.0.0.0`
     - `example.com`
     - `REPLACE_ME`
     - an old backend hostname from a different environment
   - If the target is supposed to be private, verify the hostname resolves only through the project’s private network path and not through public DNS.

   - Finally, ask whether the proxy flow matches the repo design:
     - Clients call Apigee externally.
     - Apigee routes based on `BasePath`.
     - The proxy calls a private backend over the approved internal path.
     - No direct public access to the backend is introduced.
     - No alternate, stale, or duplicate route is being created.

   - If any of those checks fail, the bundle is not ready for packaging.

4. Review the backend and security implications with a real traffic-flow mindset.
   - The main question is: “Does this proxy send requests to the right backend, and only the right backend?”
   - Read the repo flow docs and map the path: `Client -> Apigee -> proxy -> backend -> response`.
   - For this project, the intended pattern is usually:

   ```text
   Internet client
     ↓
   Apigee external entry / envgroup
     ↓
   Apigee proxy (`BasePath` route)
     ↓
   Private target endpoint (internal service / PSC / ILB path)
     ↓
   Backend app or internal service
     ↓
   Response returns along the same approved path
   ```

   - Confirm the proxy reaches the intended backend only.
     - Check the target URL itself, not just the path.
     - Confirm the backend hostname matches the actual internal service the architecture expects.
     - Confirm the proxy is not accidentally targeting a different service, test service, or public endpoint.
   - Confirm the target is the correct internal service or PSC/ILB path for this environment.
     - Match the hostname to the correct networking design in the repo.
     - Verify the backend belongs to this environment and not another project or old deployment.
   - Verify the proxy does not create a bypass, duplicate route, or conflicting deployment.
     - Check that there is only one intended path to the target.
     - Make sure the proxy does not bypass the approved WAF, Apigee, or private connectivity pattern.
     - Make sure you are not accidentally packaging a bundle from a different prototype or alternate directory such as `hello-cloudrun` when the active repo bundle should be `hello-world-proxy`.
   - If the change affects network exposure, security posture, or API behavior, record it in `changelog.md`.

5. Mark the bundle as ready for packaging.
   - Only after the above checks are complete and reviewed should the zip be created.
   - This is the release gate: the bundle is not ready until it has been validated and approved.

When to generate the zip:
- after the XML is valid and the manifest name matches the folder name
- after `BasePath`, target URL, and hostname/port checks pass
- immediately before import or re-import into the target Apigee org/environment

When to upload the zip:
- only after the bundle is reviewed and stable enough for import testing
- only to the intended Apigee org/environment
- only when the team is ready to deploy a change to live traffic

Do not commit the zip as source. The zip can be recreated from the XML at any time.

Generate the zip from the bundle directory:

```bash
cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies/hello-world-proxy
zip -r ../hello-world-proxy.zip apiproxy
```

This creates a zip whose root is `apiproxy/`, which is the format Apigee expects for import.

After the zip is created, do the following explicitly:

1. Verify the archive structure before upload.
   - Confirm the zip contains an `apiproxy/` directory at the root, not a flattened set of XML files.
   - Confirm the bundle is the expected one for this target org/environment.

2. Upload the bundle to the correct Apigee environment.
   - The upload step is intentionally separate from the XML source. The zip is a deployment artifact, not the source of truth.
   - Before uploading, confirm the target is the intended Apigee org and environment created by the Terraform setup for this repo.
   - In this project, that means the upload target must match the environment backing the `apigee_envgroup_hostnames` value in `platform/GCP/terraform/environments/DEV/dev.tfvars`, not just the proxy folder name or a guessed org.
   - Use the repo-supported management API or CLI path for your deployment, for example:

   ```bash
   cd /home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies
   zip -r hello-world-proxy.zip hello-world-proxy/apiproxy
   ```


Upload zip: 

Set variables first: 

```bash
export ORG=APIgeeOrganizationName
export PROXY_NAME=hello-world-proxy
export ENV=dev

Raplace ORG value with the apigee organization name/id. 


This one works: 

curl -X POST \
  "https://apigee.googleapis.com/v1/organizations/$ORG/apis?action=import&name=$PROXY_NAME" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -F "file=@/home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies/hello-world-proxy.zip"
```

- Deploy that revision to an environment: Tested, commands does work. 

```bash
gcloud apigee apis deploy 1   --api=hello-world-proxy   --environment=dev   --organization=rocketcodeapigee   --override
apiProxy: hello-world-proxy
deployStartTime: '1791078571460'
environment: dev
proxyDeploymentType: STANDARD
revision: '1'
```


- Verify using apigee list: 

```bash
gcloud apigee apis list
   ```

   - Verify the upload command is pointed at the correct `$ORG` and `$ENV` values before sending it.
   - Do not upload the bundle to a different org/environment just because the name looks similar. The route contract and hostnames are environment-specific.
   - After import, confirm the returned revision is the one you intended to deploy and that the imported proxy name matches the source bundle (`hello-world-proxy`).
   - If the import succeeds but the revision does not match the intended bundle, treat it as a failed deployment and correct the source before re-zipping and re-importing.

3. Import the proxy bundle into Apigee.
   - Use the standard Apigee management API or the repo’s supported deployment workflow.
   - Treat the zip as the deployment artifact, not as source code.

4. Deploy or re-deploy the imported revision.
   - Deploy only the revision that matches the validated bundle you just packaged.
   - Avoid deploying an older or alternate zip when a newer bundle is ready.

5. Validate the deployed proxy.
   - Check that the environment route is active.
   - Confirm the target backend is reachable through the configured path.
   - Test the API endpoint with the expected request/response behavior.
   - Verify logs, metrics, and failures are clean and aligned with the expected traffic flow.

6. Record the outcome.
   - If deployment succeeds, note the revision and environment in your operational record.
   - If deployment fails, capture the issue and fix the XML source before re-creating the zip and retrying.

The zip is a packaging artifact for deployment. The XML under `apiproxy/` remains the authoritative source of truth, and any change should be reviewed, validated, and then re-zipped immediately before upload.

### Internal validation when no real domain exists

This project is a demo architecture, not a production hostname deployment. That means the value in `apigee_envgroup_hostnames` is expected to be a placeholder until a real DNS name and certificate are assigned. The proxy logic can still be validated internally without a public domain by overriding the `Host` header and/or mapping the placeholder hostname locally.

Use the following pattern:

1. Confirm the route contract.
   - The envgroup hostname is the placeholder value in `platform/GCP/terraform/environments/DEV/dev.tfvars`.
   - The API path is the `BasePath` in `apiproxy/proxies/default.xml`.
   - For this demo, that means the route is expected to look like:

   ```text
   https://api.example.com/hello
   ```

   even though `api.example.com` is not a real public domain.

2. Override the Host header during local validation.
   - If you can reach the external Apigee endpoint from your terminal, send the request with the placeholder host header:

   ```bash
   curl -k -H 'Host: api.example.com' \
     "https://<apigee-external-endpoint>/hello"
   ```

   This works because Apigee matches the request hostname (through the `Host` header) to the envgroup hostname, even when the DNS name is only a local placeholder.

3. Optionally map the placeholder host locally.
   - On a local machine or test host, add a DNS override so `api.example.com` resolves to the external Apigee endpoint IP or hostname:

   ```bash
   echo "<apigee-external-ip> api.example.com" | sudo tee -a /etc/hosts
   ```

   Then test with:

   ```bash
   curl -k "https://api.example.com/hello"
   ```

   If a direct DNS entry is not available, the `curl -H 'Host: api.example.com'` method is the most reliable demo option.

4. Keep the route contract and architecture honest.
   - The public host is still placeholder-only until a real custom domain is assigned.
   - The internal/private target remains the PSC endpoint host in the `TargetEndpoint`.
   - The design remains valid for demo and validation because the routing contract is still correct even without the domain being externally routable.

This is the intended internal demo method: validate the proxy path and backend flow without requiring a production domain, while clearly documenting that the hostname is a placeholder until DNS and TLS are real.
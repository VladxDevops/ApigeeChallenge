# Rocket Code Cloud Run Backend — Implementation Requirements

## 1. Purpose

Build a **very small, lightweight HTTP API container** for the Rocket Code Cloud Engineer / DevOps technical exercise.

This is NOT intended to be a production application or a complex Hotel Events application.

Its purpose is to provide a realistic backend target that allows the infrastructure team to prove and demonstrate:

```text
External Client
    ↓
Regional External Application Load Balancer
    ↓
Cloud Armor
    ↓
Northbound PSC
    ↓
Apigee
    ↓
Southbound PSC
    ↓
Private Backend Layer
    ↓
Cloud Run
    ↓
HTTP Response
```

The backend must therefore be:

- simple
- deterministic
- fast to build
- easy to deploy
- easy to test
- easy to observe
- small enough to keep container size low
- secure by default

Do not add application complexity that does not help validate the Rocket Code architecture.

---

# 2. Scope

## Required

Build a small HTTP API service for Cloud Run.

The service must provide enough behavior to test:

- connectivity
- HTTP routing
- Apigee proxying
- PSC
- authentication/authorization integration
- response handling
- logging
- latency observation
- health checks

## Explicitly out of scope

Do NOT add:

- database
- Redis
- Pub/Sub
- Kubernetes
- service mesh
- multiple application services
- complex business logic
- frontend/UI
- user registration
- persistent application state
- complex authentication implementation inside the container
- CI/CD pipeline

The infrastructure deployment remains Terraform-driven.

Cloud Build is only used for building the container image when necessary; it is NOT a full CI/CD deployment pipeline.

---

# 3. Recommended application

Use a minimal Python HTTP framework such as Flask unless repository standards or another practical choice make a different implementation more appropriate.

Target structure:

```text
cloud-run-backend/
├── app.py
├── requirements.txt
├── Dockerfile
├── .dockerignore
├── .env.example
├── cloudbuild.yaml
└── README.md
```

The exact structure may be adapted to the existing repository, but do not create unnecessary files.

---

# 4. API endpoints

Implement at minimum:

## GET /health

Purpose:

- health/readiness-style check
- simple connectivity validation
- load-balancer/backend health troubleshooting

Expected response:

```json
{
  "status": "healthy"
}
```

HTTP status:

```text
200 OK
```

The endpoint should not require complex application authentication.

Do not expose sensitive information.

---

## GET /hello

Expected response:

```json
{
  "message": "Hello from the Rocket Code Cloud Run backend"
}
```

HTTP status:

```text
200 OK
```

This is the simplest functional endpoint for proving:

```text
Apigee → private connectivity → Cloud Run
```

---

## GET /api/test

This is the primary diagnostic endpoint.

Expected response should include only non-sensitive diagnostic information, for example:

```json
{
  "service": "rocketcode-demo-backend",
  "status": "ok",
  "message": "Request reached Cloud Run",
  "request_id": "...",
  "timestamp": "..."
}
```

Do not expose:

- secrets
- environment credentials
- access tokens
- service-account information
- internal filesystem contents
- private configuration
- full request headers

Only expose information that is useful for testing.

---

# 5. Optional latency-test behavior

Implement this only if it remains very small and clean.

Allow:

```text
GET /api/test?delay_ms=100
```

or similar.

Supported test values can be small and bounded, for example:

```text
0
100
500
1000
```

The purpose is to provide a controlled way to demonstrate latency observations through:

- Apigee
- Cloud Monitoring
- Cloud Trace
- load balancer telemetry
- Cloud Run telemetry

IMPORTANT:

This artificial delay is ONLY a diagnostic/testing feature.

It must NOT be presented as a simulation of the real on-premises Java/database latency.

The parameter must be validated and bounded.

Never allow arbitrary huge sleep values.

If the implementation adds unnecessary complexity, omit this feature.

---

# 6. Request correlation

Where practical, support a request/correlation identifier.

For example:

- accept an existing safe request ID header when appropriate
- otherwise generate a request ID

Return the identifier in the diagnostic response.

Log the same identifier.

Do not trust arbitrary sensitive headers blindly.

The goal is to make it easier to correlate:

```text
Client
→ Load Balancer
→ Apigee
→ Cloud Run
→ Cloud Logging
→ Trace
```

---

# 7. Logging

Use structured logging where practical.

Log only information useful for troubleshooting.

Examples:

- request path
- method
- status
- latency
- request ID
- service name

Do NOT log:

- passwords
- tokens
- authorization headers
- secret values
- private keys
- complete sensitive request bodies

Logging should work naturally with Google Cloud Logging.

---

# 8. Security requirements

Security is a high priority.

The container must:

- run as a non-root user
- contain no hard-coded secrets
- contain no service-account keys
- avoid unnecessary Linux packages
- avoid unnecessary dependencies
- avoid unnecessary open ports
- bind to the required Cloud Run port
- handle invalid input safely
- validate the latency parameter if implemented
- avoid exposing debug mode
- avoid development-only configuration in production
- use environment variables for non-secret configuration
- use Secret Manager for actual secrets when a secret is required

Do NOT put production secrets in `.env`.

---

# 9. `.env` handling

A `.env` file may be used for LOCAL DEVELOPMENT ONLY if useful.

Requirements:

- create `.env.example`
- document required variables
- NEVER commit real secrets
- NEVER put production credentials in `.env`
- add `.env` to `.gitignore`
- ensure Docker build does not copy `.env`
- Cloud Run production configuration should use Terraform/environment configuration and Secret Manager rather than committed `.env` files

Example:

```text
PORT=8080
SERVICE_NAME=rocketcode-demo-backend
```

Use only non-sensitive local configuration in `.env.example`.

---

# 10. Docker requirements

The container MUST be optimized for:

- small image size
- reduced attack surface
- reproducible builds
- fast startup
- minimal dependencies

Use a **multi-stage Docker build** where it provides a practical benefit.

Preferred conceptual structure:

```text
Stage 1
  ↓
build/install dependencies
  ↓
Stage 2
  ↓
minimal runtime image
```

Do not copy build tools into the final runtime image unless required.

Avoid unnecessary OS packages.

Use a small appropriate Python base image.

The final image should contain only what is needed to run the service.

---

# 11. `.dockerignore`

A `.dockerignore` file is REQUIRED.

At minimum consider excluding:

```text
.git
.gitignore
.env
.env.*
__pycache__
*.pyc
.pytest_cache
.venv
venv
tests/__pycache__
Dockerfile*
README*
docs/
terraform/
.git/
```

Adjust the exclusions to the actual repository structure.

Do not exclude files required for the Docker build.

The objective is:

1. smaller build context
2. faster builds
3. reduced accidental secret leakage
4. reduced accidental inclusion of development files

IMPORTANT:

`.dockerignore` is NOT a substitute for secret management.

Never rely on `.dockerignore` alone to protect a secret.

---

# 12. Dockerfile security

The final image should:

- run as non-root
- expose only the application port
- use an appropriate production server
- avoid debug mode
- use deterministic dependency installation
- minimize layers where practical
- avoid unnecessary packages
- avoid shell-based commands when a safer direct command is practical
- avoid embedding secrets

If using Flask, consider a lightweight production WSGI server such as Gunicorn instead of Flask's development server.

Example conceptual command:

```text
gunicorn --bind 0.0.0.0:$PORT app:app
```

Use the correct configuration for the selected framework.

---

# 13. Dependency management

Keep `requirements.txt` minimal.

Do not add libraries unless they are actually needed.

At minimum, likely dependencies are:

```text
Flask
gunicorn
```

Pin versions or use an appropriate reproducibility strategy consistent with the repository.

Avoid dependency bloat.

---

# 14. Cloud Run compatibility

The application must:

- listen on `0.0.0.0`
- use the `PORT` environment variable
- default safely to the expected Cloud Run port
- start quickly
- terminate gracefully where practical
- return valid HTTP status codes
- avoid local persistent storage assumptions

The application must work correctly when Cloud Run creates multiple instances.

Do not depend on:

- local persistent files
- in-memory shared state
- a specific container hostname
- a fixed instance ID
- a specific VM
- a specific zone

---

# 15. Cloud Run security model

The application will be placed behind the Rocket Code private architecture.

The infrastructure team should configure Cloud Run ingress according to the selected architecture so that the service cannot be used as an unintended Internet bypass.

The application itself should NOT implement network-level access controls that belong in:

- Cloud Armor
- Load Balancing
- PSC
- VPC/firewall controls
- IAM

Keep responsibilities separated.

Application security handles application behavior.

Infrastructure security handles network exposure.

---

# 16. Cloud Build

Use Cloud Build **only for container image construction**.

This project does NOT require a CI/CD pipeline.

Expected flow:

```text
Developer
   |
   | source code
   v
Cloud Build
   |
   | docker build
   v
Artifact Registry
   |
   v
Cloud Run
```

Terraform remains responsible for infrastructure deployment.

Do NOT create:

- automated deployment pipelines
- GitHub Actions
- GitLab pipelines
- continuous deployment triggers
- Cloud Build deploy stages

unless specifically requested later.

---

# 17. `cloudbuild.yaml`

Create a minimal `cloudbuild.yaml` that:

1. builds the Docker image
2. tags it appropriately
3. pushes it to Artifact Registry

Do not deploy Cloud Run from Cloud Build.

Terraform should reference the resulting image.

Use substitutions/environment variables where useful, for example:

```text
_PROJECT_ID
_REGION
_REPOSITORY
_IMAGE_NAME
```

Do not hard-code credentials.

Use Google Cloud's native build identity/permissions rather than embedding service-account keys.

---

# 18. Artifact Registry

The image should be stored in Google Artifact Registry.

The final infrastructure should define the repository through Terraform where practical.

Recommended conceptual naming:

```text
REGION-docker.pkg.dev/PROJECT_ID/REPOSITORY/IMAGE:TAG
```

Do not hard-code the real project ID in application source code.

---

# 19. Application configuration

Keep application configuration minimal.

Possible non-secret variables:

```text
PORT
SERVICE_NAME
ENVIRONMENT
LOG_LEVEL
```

Only introduce a variable when it has a real purpose.

Do not create a large configuration system.

---

# 20. Testing requirements

Provide minimal tests.

At minimum verify:

- `/health` returns 200
- `/hello` returns 200
- `/api/test` returns 200
- invalid latency values are rejected if latency simulation exists
- service starts successfully
- container runs as non-root
- production server starts correctly

Optional:

- unit tests for API handlers
- container smoke test
- local Docker test

Keep tests lightweight.

---

# 21. Local validation

The agent should validate locally where possible:

```text
python -m compileall .
```

and/or the appropriate framework test command.

Build:

```text
docker build
```

Run:

```text
docker run
```

Test:

```text
curl /health
curl /hello
curl /api/test
```

If latency support exists:

```text
curl "/api/test?delay_ms=100"
```

Verify that the response is valid JSON.

---

# 22. Container validation

Check:

- [ ] image builds successfully
- [ ] image is reasonably small
- [ ] no `.env` is copied into the image
- [ ] no credentials are present
- [ ] no unnecessary files are present
- [ ] container runs as non-root
- [ ] port is configurable
- [ ] application starts without debug mode
- [ ] health endpoint works

If container scanning is available, run it.

Address critical/high issues before considering the container complete.

---

# 23. Cloud validation

After Terraform deploys Cloud Run:

- [ ] Revision becomes ready.
- [ ] Service is reachable through the intended private architecture.
- [ ] Direct public bypass is not possible under the selected ingress configuration.
- [ ] `/health` works.
- [ ] `/hello` works.
- [ ] `/api/test` works.
- [ ] Cloud Logging receives application logs.
- [ ] request IDs can be correlated.
- [ ] latency can be observed where supported.

Do not treat a direct `run.app` request as sufficient proof of the Rocket Code architecture.

The important test is the intended path:

```text
External Client
→ Regional External Application Load Balancer
→ Cloud Armor
→ PSC
→ Apigee
→ PSC
→ Cloud Run
```

---

# 24. Documentation required from the agent

Create/update a concise:

`README.md`

Include:

- purpose
- architecture role
- endpoints
- local development
- Docker build
- Cloud Build build procedure
- Artifact Registry image
- Cloud Run expectations
- environment variables
- security notes
- testing commands

Also record any important implementation decisions in the project's documentation/changelog.

Do not create long application documentation.

---

# 25. Agent workflow

The agent implementing this component MUST work in stages.

## Stage 1 — Inspect

- [ ] Inspect existing repository conventions.
- [ ] Inspect existing Terraform Artifact Registry configuration.
- [ ] Inspect existing Terraform Cloud Run configuration, if any.
- [ ] Inspect naming conventions.
- [ ] Inspect region configuration.
- [ ] Inspect existing build configuration.
- [ ] Do not overwrite unrelated infrastructure.

## Stage 2 — Design

Produce a short implementation plan covering:

- framework
- endpoints
- Docker architecture
- security
- Cloud Build
- Artifact Registry
- Cloud Run integration
- tests

## Stage 3 — Implement

Implement the minimum required service.

## Stage 4 — Containerize

Implement:

- multi-stage Dockerfile
- `.dockerignore`
- non-root user
- minimal runtime

## Stage 5 — Build

Use Cloud Build for image creation when GCP build is required.

## Stage 6 — Validate

Run local/container tests and verify the expected cloud behavior.

## Stage 7 — Document

Update the concise application README and project tracking files.

---

# 26. Definition of Done

The Cloud Run backend is complete when:

- [ ] Small HTTP API exists.
- [ ] `/health` works.
- [ ] `/hello` works.
- [ ] `/api/test` works.
- [ ] Optional latency testing is implemented only if useful and simple.
- [ ] Structured/safe logging exists.
- [ ] Request correlation exists where practical.
- [ ] No secrets are hard-coded.
- [ ] `.env.example` exists if environment variables are used.
- [ ] `.env` is ignored.
- [ ] Multi-stage Dockerfile exists.
- [ ] `.dockerignore` exists.
- [ ] Final container runs as non-root.
- [ ] Final image is minimal.
- [ ] Cloud Build can build and push the image.
- [ ] Cloud Build does not perform deployment.
- [ ] Terraform remains responsible for infrastructure deployment.
- [ ] Cloud Run starts successfully.
- [ ] Cloud Run is configured for the intended private architecture.
- [ ] Basic tests pass.
- [ ] Documentation is complete.
- [ ] No unrelated repository components were modified.

---

# 27. Important design principle

This service exists to help prove the Rocket Code architecture.

Therefore:

DO NOT optimize for application sophistication.

Optimize for:

```text
Small
+
Secure
+
Observable
+
Containerized
+
Reproducible
+
Easy to test
+
Easy to explain
```

The application should be simple enough that the technical interview discussion remains focused on the architecture:

```text
Apigee
+
PSC
+
Load Balancer
+
Cloud Armor
+
Cloud Run
+
IAM
+
TLS
+
Terraform
+
Hybrid connectivity
```

not on application development.

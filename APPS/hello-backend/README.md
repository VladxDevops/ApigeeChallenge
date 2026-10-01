# Hello Backend Service — APPS/hello-backend

## Overview

Minimal Node.js container service designed for deployment to Google Cloud Run (`google_cloud_run_v2_service.api_backend`) behind Private Service Connect.

Serves HTTP `200 OK` status with JSON payload on port `8080`.

## Directory Structure

```text
APPS/hello-backend/
├── Dockerfile          # Multi-stage non-root container build (node:20-slim, UID 10001)
├── .dockerignore       # Docker build context exclusion list
├── .gitignore          # Git exclusion list (.env, node_modules)
├── .env.example        # Environment variable template
├── .env                # Local development variables (gitignored & dockerignored)
├── cloudbuild.yaml     # Cloud Build pipeline for Artifact Registry
├── package.json        # Node.js manifest
└── src/
    └── index.js        # HTTP server implementation (port 8080)
```

## Build & Test Locally

```bash
cd APPS/hello-backend
docker build -t hello-backend:local .
docker run -p 8080:8080 hello-backend:local
curl http://localhost:8080/
```

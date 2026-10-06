#!/usr/bin/env bash
# Connectivity Test Suite for Apigee Challenge Architecture
# Supports live HTTP testing and dry-run static environment parameter verification.

set -euo pipefail

MODE="${1:-static}"
ENDPOINT_URL="${2:-https://api.example.com/v1/hello}"

echo "=========================================="
echo " Apigee Challenge Connectivity Test Suite "
echo " Mode: ${MODE}"
echo "=========================================="

if [ "${MODE}" = "live" ]; then
    echo "[TEST 1] Testing DNS Resolution for ${ENDPOINT_URL}..."
    HOST=$(echo "${ENDPOINT_URL}" | awk -F/ '{print $3}')
    dig +short "${HOST}" || echo "[WARN] DNS resolution failed or host not registered."

    echo "[TEST 2] Testing HTTPS Ingress via Regional Load Balancer..."
    curl -k -i -m 10 "${ENDPOINT_URL}" || echo "[FAIL] Live connection blocked or endpoint unreachable."

    echo "[TEST 3] Testing Negative Ingress (Direct Cloud Run URL bypass attempt)..."
    if [ -n "${CLOUD_RUN_URL:-}" ]; then
        curl -i -m 5 "${CLOUD_RUN_URL}" && echo "[FAIL] Cloud Run directly accessible!" || echo "[PASS] Direct Cloud Run ingress blocked as expected."
    fi
else
    echo "[STATIC CHECK 1] Verifying Spoke VPC Subnet Ranges in dev.tfvars..."
    grep -E "api_private_subnet_cidr|psc_nat_subnet_cidr|proxy_only_subnet_cidr" platform/GCP/terraform/environments/DEV/dev.tfvars

    echo "[STATIC CHECK 2] Verifying Cloud Run Internal Ingress Setting..."
    grep -E "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER|INGRESS_TRAFFIC_INTERNAL_ONLY" platform/GCP/terraform/modules/infrastructure/cloudrun.tf

    echo "[STATIC CHECK 3] Verifying Non-VPC-Peering Apigee Configuration..."
    grep "disable_vpc_peering = true" platform/GCP/terraform/modules/apigee/main.tf

    echo "[PASS] All static connectivity parameters verified successfully."
fi

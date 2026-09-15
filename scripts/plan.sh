#!/usr/bin/env bash
set -euo pipefail

echo "Plan: placeholder for terraform plan wrapper"
if command -v terraform >/dev/null 2>&1; then
  echo "terraform available"
else
  echo "terraform not installed"
fi

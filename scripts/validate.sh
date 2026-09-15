#!/usr/bin/env bash
set -euo pipefail

echo "Validate: basic repository checks"
# Placeholder: validate Terraform files exist and basic linting
if [ -d "terraform" ]; then
  echo "terraform/ present"
else
  echo "terraform/ missing"
fi

echo "Done"

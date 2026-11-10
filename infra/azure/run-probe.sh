#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copy this repo onto the build VM and run infra/azure/probe.sh.
# No public IP. Azure Run Command is the access path.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
payload=$(mktemp)
remote=$(mktemp)
trap 'rm -f "$payload" "$remote"' EXIT
tar -C "$root" \
  --exclude .git \
  --exclude .venv \
  --exclude __pycache__ \
  --exclude .pytest_cache \
  -czf - . | base64 > "$payload"
bytes=$(wc -c < "$payload" | tr -d ' ')
if [ "$bytes" -gt 200000 ]; then
  echo "payload is too large for run-command ($bytes bytes)" >&2
  exit 1
fi
{
  printf '%s\n' '#!/bin/bash'
  printf '%s\n' 'set -eu'
  printf '%s\n' "base64 -d > /tmp/mt4-runtime-src.tgz <<'ENDPAYLOAD'"
  cat "$payload"
  printf '%s\n' 'ENDPAYLOAD'
  printf '%s\n' 'mkdir -p /opt/src'
  printf '%s\n' 'rm -rf /opt/src/*'
  printf '%s\n' 'tar -xzf /tmp/mt4-runtime-src.tgz -C /opt/src'
  printf '%s\n' 'bash /opt/src/infra/azure/probe.sh'
} > "$remote"
az vm run-command invoke \
  --resource-group mt4-runtime-build-rg \
  --name mt4-runtime-build \
  --command-id RunShellScript \
  --scripts @"$remote"

#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Runs on the build VM. Builds the image, checks the smoke test, checks that
# a tunnel token is not written into our logs, then installs the terminal.
set -eu
echo "probe start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
ready=0
i=0
while [ "$i" -lt 60 ]; do
  if docker info >/dev/null 2>&1; then
    ready=1
    break
  fi
  i=$((i + 1))
  sleep 5
done
if [ "$ready" -ne 1 ]; then
  echo "docker did not come up" >&2
  exit 1
fi
cd /opt/src
docker build -t mt4-runtime:probe .
echo "SMOKE"
docker run --rm --entrypoint /opt/mt4-runtime/scripts/smoke.sh mt4-runtime:probe
echo "TUNNEL"
canary="probe-canary-$(date +%s)"
docker rm -f mt4-tunnel-probe >/dev/null 2>&1 || true
docker run -d --name mt4-tunnel-probe \
  -e CLOUDFLARE_TUNNEL_TOKEN="$canary" \
  -e MT4_INSTALL=0 \
  -e MT4_REQUIRE_TERMINAL=0 \
  mt4-runtime:probe
sleep 8
hits=$(mktemp)
if docker exec mt4-tunnel-probe grep -R -l -F -- "$canary" /home/trader/log /var/run/mt4 >"$hits" 2>/dev/null; then
  echo "TOKEN_IN_LOGS" >&2
  cat "$hits" >&2
  docker rm -f mt4-tunnel-probe >/dev/null 2>&1 || true
  exit 1
fi
docker rm -f mt4-tunnel-probe >/dev/null 2>&1 || true
echo "INSTALL"
docker run --rm -e MT4_INSTALL_ONLY=1 mt4-runtime:probe
echo "probe ok $(date -u +%Y-%m-%dT%H:%M:%SZ)"

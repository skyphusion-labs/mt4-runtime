#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
pidfile=/var/run/mt4/xvfb.pid
if [ ! -f "$pidfile" ]; then
  echo "xvfb pid file is missing" >&2
  exit 1
fi
pid=$(cat "$pidfile")
kill -0 "$pid"
if [ -f /var/run/mt4/tunnel.requested ]; then
  tpid=$(cat /var/run/mt4/cloudflared.pid)
  kill -0 "$tpid"
fi
exit 0

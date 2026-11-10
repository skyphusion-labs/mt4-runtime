#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Starts as root so it can hand the prefix volume to the trader user, then
# drops privileges before Wine or cloudflared run.
set -eu

export DISPLAY="${DISPLAY:-:99}"
export WINEPREFIX="${WINEPREFIX:-/home/trader/.mt4}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
export HOME="${HOME:-/home/trader}"

if [ "$(id -u)" -eq 0 ]; then
  mkdir -p "$WINEPREFIX" "$HOME/log" /var/run/mt4
  chown -R trader:trader "$WINEPREFIX" "$HOME" /var/run/mt4
  exec runuser --preserve-environment -u trader -- "$0" "$@"
fi

mkdir -p "$HOME/log" /var/run/mt4

Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >"$HOME/log/xvfb.log" 2>&1 &
echo $! >/var/run/mt4/xvfb.pid

ready=0
i=0
while [ "$i" -lt 50 ]; do
  if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    ready=1
    break
  fi
  i=$((i + 1))
  sleep 0.1
done
if [ "$ready" -ne 1 ]; then
  echo "display $DISPLAY did not come up" >&2
  exit 1
fi

# Wine dialogs do not take clicks on a bare Xvfb. A window manager has to
# own the display first.
openbox >"$HOME/log/openbox.log" 2>&1 &
echo $! >/var/run/mt4/openbox.pid

if [ -n "${CLOUDFLARE_TUNNEL_TOKEN:-}" ]; then
  : >/var/run/mt4/tunnel.requested
  # The token is passed only in the child environment, then dropped here.
  TUNNEL_TOKEN="$CLOUDFLARE_TUNNEL_TOKEN" \
    cloudflared tunnel --no-autoupdate run >"$HOME/log/cloudflared.log" 2>&1 &
  echo $! >/var/run/mt4/cloudflared.pid
  unset CLOUDFLARE_TUNNEL_TOKEN
  unset TUNNEL_TOKEN
fi

if [ "${MT4_INSTALL:-1}" != "0" ]; then
  /opt/mt4-runtime/scripts/install-mt4.sh
fi

if [ "${MT4_INSTALL_ONLY:-0}" = "1" ]; then
  exit 0
fi

if [ "${MT4_REQUIRE_TERMINAL:-1}" = "0" ]; then
  while kill -0 "$(cat /var/run/mt4/xvfb.pid)" 2>/dev/null; do
    sleep 30
  done
  exit 1
fi

terminal=$(python3 -m mt4runtime find-terminal --prefix "$WINEPREFIX" || true)
if [ -z "$terminal" ]; then
  echo "terminal.exe is not installed" >&2
  exit 1
fi
printf '%s\n' "$terminal" >/var/run/mt4/terminal.path
exec wine "$terminal"

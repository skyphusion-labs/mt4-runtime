#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Download the MetaQuotes installer and run it under Wine.
# The terminal is not part of the image. Running this is the operator
# accepting the MetaQuotes license on this machine.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
if [ -z "${PYTHONPATH:-}" ]; then
  PYTHONPATH="$ROOT"
fi
export PYTHONPATH

PREFIX="${WINEPREFIX:-/home/trader/.mt4}"
existing=$(python3 -m mt4runtime find-terminal --prefix "$PREFIX" || true)
if [ -n "$existing" ]; then
  printf '%s\n' "$existing"
  exit 0
fi

if [ -z "${MT4_SETUP_URL:-}" ]; then
  URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4oldsetup.exe"
else
  URL="$MT4_SETUP_URL"
fi

if [ "${MT4_ALLOW_UNLISTED_SETUP_HOST:-0}" = "1" ]; then
  URL=$(python3 -m mt4runtime validate-url --url "$URL" --allow-unlisted)
else
  URL=$(python3 -m mt4runtime validate-url --url "$URL")
fi

if [ "${MT4_DRY_RUN:-0}" = "1" ]; then
  printf 'dry-run %s\n' "$URL"
  exit 0
fi

if [ -z "${DISPLAY:-}" ]; then
  echo "DISPLAY is not set" >&2
  exit 1
fi

export WINEPREFIX="$PREFIX"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
mkdir -p "$PREFIX" "${HOME:-/tmp}/log"

installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl --proto '=https' --tlsv1.2 -fL --retry 3 --retry-delay 2 -o "$installer" "$URL"
size=$(wc -c < "$installer" | tr -d ' ')
if [ "$size" -lt 100000 ]; then
  echo "installer download is too small" >&2
  exit 1
fi

if [ ! -f "$PREFIX/system.reg" ]; then
  wineboot --init
  wineserver --wait
fi
winecfg -v=win10
wineserver --wait || true

log="${HOME:-/tmp}/log/install.log"
wine "$installer" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- >"$log" 2>&1 || true
wineserver --wait || true

found=$(python3 -m mt4runtime find-terminal --prefix "$PREFIX" || true)
if [ -z "$found" ]; then
  echo "terminal.exe was not installed" >&2
  if [ -f "$log" ]; then
    tail -n 80 "$log" >&2
  fi
  exit 1
fi
printf '%s\n' "$found"

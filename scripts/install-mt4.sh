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

log="${HOME:-/tmp}/log/install.log"
: >"$log"

# winecfg is a GUI and it waits forever under Xvfb. Set the version in
# the registry after a bounded wineboot instead.
if ! timeout 90 wineboot --init >>"$log" 2>&1; then
  echo "wineboot did not finish" >&2
  tail -n 40 "$log" >&2 || true
  wineserver -k >/dev/null 2>&1 || true
  exit 1
fi
wineserver --wait >>"$log" 2>&1 || true
timeout 20 wine reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d win10 /f >>"$log" 2>&1 || true

# The MetaQuotes file is a GUI setup. Silent Inno flags are ignored and
# the window waits forever. Drive the visible window until a terminal exists.
wine "$installer" >>"$log" 2>&1 &
wine_pid=$!

nudge() {
  ids=$(xdotool search --onlyvisible --name "MetaTrader" 2>/dev/null || true)
  if [ -z "$ids" ]; then
    ids=$(xdotool search --onlyvisible --name "Setup" 2>/dev/null || true)
  fi
  if [ -z "$ids" ]; then
    return 0
  fi
  id=$(printf '%s\n' $ids | head -n 1)
  case "$1" in
    0) key=space ;;
    1) key=alt+a ;;
    2) key=alt+n ;;
    3) key=alt+i ;;
    *) key=Return ;;
  esac
  xdotool windowactivate --sync "$id" key --delay 40 "$key" >/dev/null 2>&1 || true
}

i=0
found=""
while [ "$i" -lt 160 ]; do
  found=$(python3 -m mt4runtime find-terminal --prefix "$PREFIX" || true)
  if [ -n "$found" ]; then
    break
  fi
  if [ $((i % 5)) -eq 0 ]; then
    echo "install wait $i" >&2
    xwininfo -root -tree 2>/dev/null | awk 'length($0) < 220 && /"[^"]+"/ {print}' | head -n 12 >&2 || true
    tail -n 4 "$log" >&2 || true
  fi
  nudge $((i % 5))
  i=$((i + 1))
  sleep 3
done

wineserver -k >/dev/null 2>&1 || true
kill "$wine_pid" >/dev/null 2>&1 || true

if [ -z "$found" ]; then
  found=$(python3 -m mt4runtime find-terminal --prefix "$PREFIX" || true)
fi
if [ -z "$found" ]; then
  echo "terminal was not installed" >&2
  tail -n 80 "$log" >&2 || true
  exit 1
fi
printf '%s\n' "$found"

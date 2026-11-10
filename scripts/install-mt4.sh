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
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
# Unset before wineboot. The installer treats a wineserver that was
# started with WINEDEBUG set as a debugger, even when the setup
# process itself does not have the variable.
unset WINEDEBUG
wineserver -k >/dev/null 2>&1 || true
mkdir -p "$PREFIX" "${HOME:-/tmp}/log"

installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl --proto '=https' --tlsv1.2 -fL --retry 3 --retry-delay 2 -o "$installer" "$URL"
chmod 700 "$installer"
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
# the window waits forever. The installer reads AeDebug and stops with
# "a debugger has been found" when that value names winedbg. Clear it,
# and do not pass WINEDEBUG into the setup process.
# Drive the visible window until a terminal exists.
for view in 32 64; do
  env -u WINEDEBUG wine reg add \
    'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' \
    /v Auto /t REG_SZ /d 0 /f /reg:"$view" >>"$log" 2>&1 || true
  env -u WINEDEBUG wine reg delete \
    'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' \
    /v Debugger /f /reg:"$view" >>"$log" 2>&1 || true
done
env -u WINEDEBUG wine "$installer" >>"$log" 2>&1 &
wine_pid=$!

# The setup window title is the exe name, not "MetaTrader", until the
# real wizard paints. Pick the first sized window that is not Explorer.
nudge() {
  id=$(xwininfo -root -tree 2>/dev/null | awk '
    /explorer\.exe/ { next }
    /Default IME/ { next }
    /has no name/ { next }
    /[0-9][0-9][0-9]x/ {
      print $1
      exit
    }
  ')
  if [ -z "$id" ]; then
    return 0
  fi
  echo "click $id" >&2
  xdotool getwindowname "$id" >&2 || true
  timeout 5 xdotool windowactivate "$id" key --window "$id" alt+n >/dev/null 2>&1 || true
  timeout 5 xdotool mousemove --window "$id" 250 80 click --window "$id" 1 >/dev/null 2>&1 || true
}

probe_terminal() {
  probe_err=$(mktemp)
  probe_status=0
  probe_path=$(python3 -m mt4runtime find-terminal --prefix "$PREFIX" 2>"$probe_err") || probe_status=$?
  if [ "$probe_status" -eq 3 ]; then
    cat "$probe_err" >&2
    rm -f "$probe_err"
    wineserver -k >/dev/null 2>&1 || true
    exit 1
  fi
  rm -f "$probe_err"
}

i=0
found=""
last_count=""
settled=0
while [ "$i" -lt 160 ]; do
  probe_terminal
  if [ -n "$probe_path" ]; then
    found=$probe_path
  fi
  alive=0
  if kill -0 "$wine_pid" 2>/dev/null; then
    alive=1
  fi
  if [ -n "$found" ]; then
    if [ "$alive" -eq 0 ]; then
      echo "installer process exited" >&2
      break
    fi
    install_dir=$(dirname "$found")
    now=$(find "$install_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$now" = "$last_count" ]; then
      settled=$((settled + 1))
    else
      settled=0
      last_count=$now
    fi
    # Five unchanged polls at 3 seconds is 15 seconds.
    if [ "$settled" -ge 5 ]; then
      echo "install tree stable at $now files" >&2
      break
    fi
  elif [ "$alive" -eq 0 ]; then
    echo "installer process exited" >&2
    break
  fi
  if [ $((i % 5)) -eq 0 ]; then
    if [ "$alive" -eq 1 ]; then
      echo "install wait $i wine=$wine_pid" >&2
    else
      echo "install wait $i wine exited" >&2
    fi
    xwininfo -root -tree 2>/dev/null | awk 'length($0) < 220 && /"[^"]+"/ {print}' | head -n 12 >&2 || true
    tail -n 4 "$log" >&2 || true
  fi
  nudge
  i=$((i + 1))
  sleep 3
done

wineserver -k >/dev/null 2>&1 || true

if [ -z "$found" ]; then
  probe_terminal
  found=$probe_path
fi
if [ -z "$found" ]; then
  echo "terminal was not installed" >&2
  tail -n 80 "$log" >&2 || true
  exit 1
fi
printf '%s\n' "$found"

#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
command -v wine
command -v cloudflared
wine --version
cloudflared --version
python3 -m mt4runtime validate-url \
  --url "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4oldsetup.exe" \
  >/dev/null
found=$(python3 -m mt4runtime find-terminal --prefix "${WINEPREFIX:-/home/trader/.mt4}" || true)
if [ -n "$found" ]; then
  echo "terminal.exe must not be baked into the image" >&2
  exit 1
fi
echo "smoke ok"

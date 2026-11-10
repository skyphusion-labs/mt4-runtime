#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
command -v wine
command -v cloudflared
command -v git
command -v python3.12
wine --version
cloudflared --version
git --version
py=$(python3.12 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
if [ "$py" != "3.12" ]; then
  echo "python is $py, want 3.12" >&2
  exit 1
fi
python3.12 -m venv --help >/dev/null
python3.12 -m pip --version
python3 -m mt4runtime validate-url \
  --url "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4oldsetup.exe" \
  >/dev/null
found=$(python3 -m mt4runtime find-terminal --prefix "${WINEPREFIX:-/home/trader/.mt4}" || true)
if [ -n "$found" ]; then
  echo "terminal.exe must not be baked into the image" >&2
  exit 1
fi
echo "smoke ok"

# SPDX-License-Identifier: Apache-2.0
"""Rules for the installer URL and the Wine prefix."""

from __future__ import annotations

import os
from urllib.parse import urlparse

DEFAULT_SETUP_URL = (
    "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4oldsetup.exe"
)
ALLOWED_HOSTS = frozenset({"download.mql5.com"})


class SetupUrlError(ValueError):
    """The installer URL is not one this image will fetch."""


def validate_setup_url(url: str, *, allow_unlisted_host: bool = False) -> str:
    """Return a safe https installer URL, or raise SetupUrlError."""
    text = url.strip()
    if not text:
        raise SetupUrlError("setup url is empty")
    parsed = urlparse(text)
    if parsed.scheme != "https":
        raise SetupUrlError("setup url must use https")
    if parsed.username or parsed.password:
        raise SetupUrlError("setup url must not carry credentials")
    host = parsed.hostname
    if not host:
        raise SetupUrlError("setup url has no host")
    if host not in ALLOWED_HOSTS and not allow_unlisted_host:
        raise SetupUrlError("setup url host is not allowed")
    if parsed.query or parsed.fragment:
        raise SetupUrlError("setup url must not carry a query or fragment")
    return text


def find_terminal(prefix: str) -> str | None:
    """Return the first terminal.exe under prefix, or None."""
    if not prefix or not prefix.strip():
        return None
    root = os.path.abspath(prefix)
    if not os.path.isdir(root):
        return None
    found: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [name for name in dirnames if name != "dosdevices"]
        for name in filenames:
            if name.lower() == "terminal.exe":
                found.append(os.path.join(dirpath, name))
    if not found:
        return None
    found.sort()
    return found[0]

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


class WrongTerminalError(Exception):
    """The prefix has terminal64.exe and no MT4 terminal.exe."""

    def __init__(self, path: str) -> None:
        super().__init__(path)
        self.path = path


def find_terminal(prefix: str) -> str | None:
    """Return terminal.exe under prefix, or None when nothing is installed.

    terminal64.exe is MetaTrader 5. If that is the only terminal, raise
    WrongTerminalError with its path instead of treating the install as MT4.
    """
    if not prefix or not prefix.strip():
        return None
    root = os.path.abspath(prefix)
    if not os.path.isdir(root):
        return None
    exe: list[str] = []
    mt5: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [name for name in dirnames if name != "dosdevices"]
        for name in filenames:
            lowered = name.lower()
            full = os.path.join(dirpath, name)
            if lowered == "terminal.exe":
                exe.append(full)
            elif lowered == "terminal64.exe":
                mt5.append(full)
    if exe:
        exe.sort()
        return exe[0]
    if mt5:
        mt5.sort()
        raise WrongTerminalError(mt5[0])
    return None

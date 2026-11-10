# SPDX-License-Identifier: Apache-2.0
"""Rules for the installer URL and the Wine prefix."""

from __future__ import annotations

import os
from urllib.parse import urlparse

DEFAULT_SETUP_URL = (
    "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4oldsetup.exe"
)
# Measured 2026-11-10. Two downloads of DEFAULT_SETUP_URL, 4702512 bytes,
# both hashed with shasum -a 256 to this value.
DEFAULT_SETUP_SHA256 = (
    "19b1a0dbe21a3cc5e38957105a869153fd29a677c1f992303dd96eb2ad18eabd"
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


def resolve_setup_sha256(url: str, override: str = "") -> str:
    """Return the sha256 the downloaded installer must match."""
    text = override.strip().lower()
    if text:
        if len(text) != 64 or any(char not in "0123456789abcdef" for char in text):
            raise SetupUrlError("setup sha256 must be 64 hex characters")
        return text
    if url == DEFAULT_SETUP_URL:
        return DEFAULT_SETUP_SHA256
    raise SetupUrlError("a non-default setup url requires MT4_SETUP_SHA256")


def verify_setup_sha256(actual: str, expected: str) -> None:
    """Raise SetupUrlError when the downloaded bytes are not the pinned ones."""
    got = actual.strip().lower()
    if got != expected:
        raise SetupUrlError(f"installer sha256 is {got}")


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

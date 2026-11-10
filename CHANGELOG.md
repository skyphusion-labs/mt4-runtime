# Changelog

## 0.1.4

Python 3.12, venv, pip, and git are installed so a desk package that
requires Python 3.12 can be installed into a virtualenv at runtime.
That package is not in the image, and the MetaTrader5 Python package
is not installed.

## 0.1.3

The default installer download is checked against a sha256 pin, not
only a minimum size. A different URL has to bring MT4_SETUP_SHA256.
The pin is the 2026-11-10 download of mt4oldsetup.exe, 4702512 bytes.

## 0.1.2

The current MetaQuotes setup file is a GUI installer. Inno Setup silent
flags do not apply, so the run waited until the task timed out.
The container now bounds Wine startup and drives the setup window.
Wine 11 trips that installer's debugger check. The image pins
WineHQ stable at 10.0.0.0.
It looks for terminal.exe only. A lone terminal64.exe is refused.
After terminal.exe appears, the installer is left running until it
exits, or until the file count in its directory stays the same for
15 seconds. Docker's default seccomp
profile blocks Wine's server socket, so compose and CI lift it.

## 0.1.1

The Ubuntu 24.04 base image already has a user at uid 1000. Remove that
user before creating `trader`, so the image build can finish.

## 0.1.0

Initial image. Wine and cloudflared are installed at build time.
MetaTrader 4 is downloaded by the operator at start and is not stored in
the image.

# Changelog

## 0.1.2

The current MetaQuotes setup file is a GUI installer. Inno Setup silent
flags do not apply, so the run waited until the task timed out.
The container now bounds Wine startup and drives the setup window.
Wine 11 trips that installer's debugger check. The image pins
WineHQ stable at 10.0.0.0.
It looks for terminal.exe and terminal64.exe. Docker's default seccomp
profile blocks Wine's server socket, so compose and CI lift it.

## 0.1.1

The Ubuntu 24.04 base image already has a user at uid 1000. Remove that
user before creating `trader`, so the image build can finish.

## 0.1.0

Initial image. Wine and cloudflared are installed at build time.
MetaTrader 4 is downloaded by the operator at start and is not stored in
the image.

# Changelog

## 0.1.1

The Ubuntu 24.04 base image already has a user at uid 1000. Remove that
user before creating `trader`, so the image build can finish.

## 0.1.0

Initial image. Wine and cloudflared are installed at build time.
MetaTrader 4 is downloaded by the operator at start and is not stored in
the image.

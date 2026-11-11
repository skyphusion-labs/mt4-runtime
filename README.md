# mt4-runtime

Linux image that runs Wine, cloudflared, and a MetaTrader 4 terminal.

The terminal is not in the image. On first start the container downloads the
installer from MetaQuotes and runs it under Wine. You accept the MetaQuotes
license by that install. Broker logins stay on the machine, not in this
repository.

The image is linux/amd64. Python 3.12, venv, pip, and git are
installed so a desk package can be installed into a virtualenv at
runtime. That package is not in this image. Wine is pinned to 10.0
because Wine 11 makes
the MetaQuotes installer report a debugger and stop. It publishes no
ports. cloudflared starts only when
`CLOUDFLARE_TUNNEL_TOKEN` is set, and it dials out.

## License

This repository is Apache-2.0. Wine is LGPL-2.1. cloudflared is Apache-2.0.
MetaTrader 4 is a MetaQuotes program and is not shipped here. See `NOTICE`.

## Build

```sh
docker build -t mt4-runtime:local .
```

## Run

```sh
docker compose up --build
```

`docker compose` uses `seccomp/wine.json`. That is Docker's default
profile plus two allows: `clone3`, and `socket` for `AF_ALG` (38).
Without those, `wineboot` exits at once with
`wine: socket : Function not implemented`. A plain `docker run` needs
`--security-opt seccomp=seccomp/wine.json`.

Set `CLOUDFLARE_TUNNEL_TOKEN` in the environment when you want a tunnel.
Leave it unset to run without one. The Wine prefix is the `mt4-prefix`
volume. Delete that volume to remove the terminal.

`MT4_SETUP_URL` defaults to the MetaQuotes installer on
`download.mql5.com`. The bytes are checked against a sha256 pin. A
different URL has to set `MT4_SETUP_SHA256` as well. That file is a
GUI setup. Silent install flags do not apply. The container drives
the setup window. Set `MT4_ALLOW_UNLISTED_SETUP_HOST=1` only when the
installer host is somewhere else, and only for an https URL.

## Proof

```sh
pip install -r requirements-dev.txt
pytest --cov=mt4runtime --cov-fail-under=100
docker run --rm --entrypoint /opt/mt4-runtime/scripts/smoke.sh mt4-runtime:local
```

The smoke test checks that `wine` and `cloudflared` run, and that
`terminal.exe` is not in the image.

A short-lived Azure build VM is in `infra/azure`. It has no public IP and no
inbound SSH rule. Standard_B2ms in eastus was $0.0832 per hour on 2026-11-10.
Delete the resource group when the run finishes.

## Security

Report a vulnerability to conrad@skyphusion.org. Do not open a public issue
for a vulnerability.

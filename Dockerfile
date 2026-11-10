FROM ubuntu:24.04

ARG VERSION=0.1.2
ARG CLOUDFLARED_VERSION=2026.10.7
ARG CLOUDFLARED_SHA256=1f99fb518b83dec2ba8d870a7cc991d82a77e6196295a3d2754ba17ab9f91872

LABEL org.opencontainers.image.title="mt4-runtime" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/skyphusion-labs/mt4-runtime" \
      org.opencontainers.image.description="Wine and cloudflared runtime. MetaTrader 4 is installed by the operator at start."

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    WINEPREFIX=/home/trader/.mt4 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/opt/mt4-runtime \
    HOME=/home/trader

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        xvfb \
        x11-utils \
        xauth \
        procps \
        python3 \
        tini \
        xdotool \
        fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

RUN dpkg --add-architecture i386 \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
    && apt-get update \
    && apt-get install -y --install-recommends winehq-stable \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/cloudflared \
        "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-amd64" \
    && echo "${CLOUDFLARED_SHA256}  /tmp/cloudflared" | sha256sum -c - \
    && install -m 0755 /tmp/cloudflared /usr/local/bin/cloudflared \
    && rm -f /tmp/cloudflared \
    && cloudflared --version

# Ubuntu 24.04 images already have a user at uid 1000. useradd exits 4
# when that uid is taken, so remove it before creating trader.
RUN if getent passwd ubuntu >/dev/null; then userdel -r ubuntu; fi \
    && useradd --create-home --shell /bin/bash --uid 1000 --user-group trader \
    && mkdir -p /opt/mt4-runtime /home/trader/.mt4 /home/trader/log /var/run/mt4 \
    && chown -R trader:trader /home/trader /var/run/mt4 /opt/mt4-runtime

COPY mt4runtime /opt/mt4-runtime/mt4runtime
COPY entrypoint.sh /opt/mt4-runtime/entrypoint.sh
COPY scripts/ /opt/mt4-runtime/scripts/
RUN chmod 0755 /opt/mt4-runtime/entrypoint.sh /opt/mt4-runtime/scripts/*.sh \
    && chown -R trader:trader /opt/mt4-runtime

VOLUME ["/home/trader/.mt4"]
WORKDIR /home/trader
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=3 \
    CMD ["/opt/mt4-runtime/scripts/healthcheck.sh"]
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/mt4-runtime/entrypoint.sh"]

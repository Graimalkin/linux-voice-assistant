### Multi-stage build: compile in a builder, ship only the runtime venv + libs.
### Keeps build-essential (needed to compile pymicro-features) and vim OUT of the final
### image, which slims it well below the single-stage build and — crucially — breaks up the
### one giant apt layer that OOM-thrashed the 512MB Pi Zero 2 W satellites on pull.

# ---------- builder: has the compilers, produces /app (incl. .venv) ----------
FROM python:3.13-slim-trixie AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# build-essential compiles pymicro-features; libmpv-dev + ca-certificates round out the build env.
RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    build-essential \
    libmpv-dev \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY script/ ./script/
COPY pyproject.toml ./
COPY setup.cfg ./
COPY sounds/ ./sounds/
COPY ../wakewords/ ./wakewords/
COPY linux_voice_assistant/ ./linux_voice_assistant/
COPY docker-entrypoint.sh ./
COPY version.txt ./
COPY version_githash.txt ./
RUN chmod +x docker-entrypoint.sh
RUN ./script/setup

# ---------- runtime: slim, no compilers, no vim ----------
FROM python:3.13-slim-trixie

ENV LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

LABEL \
    org.opencontainers.image.authors="Open Home Foundation" \
    org.opencontainers.image.description="Voice assistant for Home Assistant (wake-capture, slim)" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.source="https://github.com/OHF-Voice/linux-voice-assistant" \
    org.opencontainers.image.title="Linux-Voice-Assistant"

### Runtime-only packages (no build-essential, no vim):
# - avahi-utils / pulseaudio-utils / alsa-utils / pipewire-*: audio + mDNS discovery
# - libmpv2:            runtime mpv lib (python-mpv loads it via ctypes; no -dev headers needed)
# - libasound2-plugins: python-mpv audio playback
# - ca-certificates / iproute2 / procps: TLS, ss (entrypoint), pgrep (healthcheck)
RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    avahi-utils \
    pulseaudio-utils \
    alsa-utils \
    pipewire-bin \
    pipewire-alsa \
    pipewire-pulse \
    libmpv2 \
    libasound2-plugins \
    ca-certificates \
    iproute2 \
    procps && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app /app

EXPOSE 6053
ENTRYPOINT ["./docker-entrypoint.sh"]

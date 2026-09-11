---
title: "OpenClaw on Docker (Production): the RemarkableCloud image"
slug: openclaw
meta_description: "Run OpenClaw on Docker in production: self-hosted AI agent gateway, digest-pinned, token-gated Control UI, local state volume, with compose and backups."
keywords:
  - openclaw docker
  - openclaw docker compose
  - self-hosted ai agent
  - openclaw gateway
  - openclaw behind traefik
  - openclaw control ui
  - self-hosted ai assistant
---

# OpenClaw on Docker, ready for production

OpenClaw is a self-hosted AI agent gateway: it runs an autonomous assistant you control from a web Control UI, connect to chat channels, and point at the LLM provider of your choice, with all state kept on your own instance. This page covers the RemarkableCloud OpenClaw image: what it is, what our build adds on top of upstream, and how to run it in production with Docker behind a reverse proxy.

## What the RemarkableCloud image adds

The image is a production-oriented build of the official OpenClaw gateway image that keeps the official runtime and adds turnkey, secured provisioning:

- **Digest-pinned base.** Built from `ghcr.io/openclaw/openclaw@sha256:cc596b846506a5f4cfcee111394a2725f375f01cca2ebb492a161fd1b747f101` (OpenClaw 2026.9.4, Node 24, Debian 12). Pinning by digest keeps rebuilds reproducible.
- **Token-gated Control UI, never open.** The gateway is started with token authentication, and our wrapper generates a strong token on first run, persists it in the data volume, and prints it once. Nothing is baked into an image layer, and the instance is never left unauthenticated on a public URL. You can pin your own with `OPENCLAW_GATEWAY_TOKEN`.
- **Reachable behind a proxy.** The gateway binds a routable interface (not loopback) and starts in an unconfigured-friendly mode, so it comes up cleanly behind a reverse proxy on first boot, before you have added an LLM key.
- **Local state, no external database.** All state lives in a single `/home/node/.openclaw` volume.
- **Healthcheck.** A container `HEALTHCHECK` polls `/health` so the platform routes traffic only once the gateway is ready.

The current published tag is `ghcr.io/remarkablecloud/openclaw:2026.9.4-r1`.

OpenClaw is a trademark of its respective owner (OpenClaw Foundation). RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **OpenClaw gateway** serves the Control UI on port `18789`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform).
- **No external database.** State, memory, and credentials live in the `/home/node/.openclaw` volume.
- **LLM provider.** OpenClaw calls an external LLM (OpenAI, Anthropic, and many others); you supply your own API key in the Control UI (or via environment).

## Docker Compose walkthrough

The standalone stack is defined in the image's `docker-compose.yml`:

```yaml
name: openclaw
services:
  openclaw:
    image: ${OPENCLAW_IMAGE:-ghcr.io/remarkablecloud/openclaw:2026.9.4-r1}
    restart: unless-stopped
    ports: ["${HTTP_PORT:-18789}:18789"]
    environment:
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN:-}
      # OPENAI_API_KEY: ${OPENAI_API_KEY:-}
    volumes:
      - openclaw-data:/home/node/.openclaw
volumes:
  openclaw-data:
```

Step by step:

1. **The token is generated if blank.** Leave `OPENCLAW_GATEWAY_TOKEN` empty and the image creates a strong one on first run, logs it once, and keeps it in the volume.
2. **Only the web port is exposed.** `${HTTP_PORT:-18789}:18789` is for local use; in production the proxy connects to port `18789` on the internal network.
3. **State lives in a volume.** `openclaw-data` (`/home/node/.openclaw`) persists the token, config, and memory across restarts and upgrades.

To start it locally:

```
docker compose up -d
```

Then read the token from `docker compose logs openclaw`, open `http://localhost:18789`, paste the token into Settings, and add your LLM API key.

## Environment variable reference

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `OPENCLAW_GATEWAY_TOKEN` | no | (generated) | Shared token for the Control UI. Leave empty to auto-generate on first run (printed once); set it to pin your own. |
| `OPENCLAW_GATEWAY_PORT` | no | `18789` | Gateway / Control UI port. |
| `OPENAI_API_KEY` (or other provider key) | no | (unset) | LLM provider key. Can be set here or in the Control UI after connecting. |

## Hardening notes

- **Token-gated by default.** The Control UI is started with token auth and a generated token; it is never open.
- **Treat the token as admin/shell access.** OpenClaw is an autonomous agent that can execute tasks and browse the web from its own container. Anyone with the token controls the agent, so keep it private and rotate it if leaked.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/health` must return success before the platform routes requests.
- **Isolated per instance.** Each deployment is its own container with its own volume and token.

## Backups

The single volume holds all state:

```
docker run --rm -v openclaw_openclaw-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/openclaw-data.tgz -C /data .
```

The `/home/node/.openclaw` volume contains the token, configuration, and agent memory. On the RemarkableCloud App Platform, volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; state persists in the volume:
  ```
  docker compose pull openclaw && docker compose up -d openclaw
  ```
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
No. OpenClaw keeps all state in the `/home/node/.openclaw` volume; there is no external database.

**How do I log in the first time?**
The gateway token is printed once to the container log on first run. Open the Control UI, paste the token into Settings, then add your LLM API key.

**Do I need my own LLM key?**
Yes. OpenClaw calls an external LLM provider (OpenAI, Anthropic, and many others); add your key in the Control UI or via environment.

**Is it safe to expose publicly?**
It is token-gated, so it is not open. But because the agent can execute tasks, treat the token as administrative access: keep it private, and rotate it if it leaks.

**How does HTTPS work if the container serves HTTP on 18789?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards to port `18789` on the internal network.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/openclaw:2026.9.4-r1`. Avoid moving tags so a redeploy cannot change the image under you.

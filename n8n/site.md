---
title: "n8n on Docker: Production Setup with the RemarkableCloud Image"
slug: "n8n"
meta_description: "Run n8n in production with Docker Compose using the RemarkableCloud digest-pinned image: SQLite, non-root, healthcheck, Traefik TLS."
keywords:
  - n8n docker
  - n8n docker compose
  - n8n self-hosted
  - n8n workflow automation
  - n8n production setup
  - n8n traefik
  - n8n sqlite
---

# Run n8n in Production with Docker

n8n is an open-source workflow automation tool with a visual, node-based editor and more than 400 integrations. You build automations by connecting triggers and actions on a canvas, and n8n runs them on a schedule, on demand, or in response to incoming webhooks. This image stores everything in SQLite, so there is no external database to run or maintain.

This page covers the RemarkableCloud n8n image: what it adds over upstream, a full docker-compose walkthrough, an environment variable reference, and hardening, backup, and upgrade guidance for a production deployment.

## What the RemarkableCloud image adds

The RemarkableCloud image is a thin, security-focused build on top of the upstream n8n image (`n8nio/n8n`, Alpine-based, which already runs as the non-root `node` user). On top of that base it adds:

- **Digest-pinned base.** The build pins the exact upstream layer by digest, so a given tag always resolves to the same bytes and is easy to audit.
- **OCI provenance labels.** Title, description, vendor, and source labels travel with the image for supply-chain traceability.
- **Built-in healthcheck.** A container `HEALTHCHECK` polls n8n's `/healthz` endpoint, so an orchestrator only sends traffic to a ready instance.
- **Writable data directory.** The build ensures `/home/node/.n8n` exists and is owned by `node`, so a mounted persistent volume is writable out of the box.

Upstream n8n's features are unchanged. The version is pinned to n8n 2.38.6 in the `2.38.6-r1` tag.

## docker-compose walkthrough

The image ships a standalone `docker-compose.yml`:

```yaml
name: n8n

services:
  n8n:
    image: ${N8N_IMAGE:-ghcr.io/remarkablecloud/n8n:2.38.6-r1}
    restart: unless-stopped
    ports: ["${HTTP_PORT:-5678}:5678"]
    environment:
      N8N_PORT: "5678"
      GENERIC_TIMEZONE: ${TZ:-UTC}
      N8N_SECURE_COOKIE: ${N8N_SECURE_COOKIE:-false}
    volumes:
      - n8n-data:/home/node/.n8n

volumes:
  n8n-data:
```

Line by line:

- **image** pins the RemarkableCloud n8n tag, overridable with the `N8N_IMAGE` variable.
- **restart: unless-stopped** brings n8n back after a crash or host reboot.
- **ports** publishes container port 5678 on the host (default 5678). This is for standalone runs only. Behind Traefik on the App Platform, no port is published; the proxy routes to the container on the internal network.
- **environment** sets the listen port, timezone, and cookie policy (see the reference below).
- **volumes** mounts the named `n8n-data` volume at `/home/node/.n8n`, which holds the SQLite database and the credential encryption key.

Start it with `docker compose up -d`, then open http://localhost:5678 and create the owner account on first visit.

## Environment variable reference

The App Platform wires these automatically from the app hostname; the standalone column shows the defaults baked into `docker-compose.yml`. Behind Traefik, TLS terminates at the proxy and the container speaks plain HTTP.

| Variable | App Platform value | Standalone default | Notes |
|---|---|---|---|
| `N8N_PORT` | `5678` | `5678` | Port n8n listens on inside the container. |
| `N8N_PROTOCOL` | `https` | not set | Tells n8n it is served over HTTPS (TLS terminates at Traefik). |
| `N8N_HOST` | your hostname | not set | Public hostname n8n serves; the platform fills this from the app hostname. |
| `N8N_EDITOR_BASE_URL` | `https://your-hostname/` | not set | Base URL of the editor. Note the trailing slash. |
| `WEBHOOK_URL` | `https://your-hostname/` | not set | Public base for generated webhook URLs. It must match the real domain or inbound webhooks break. Note the trailing slash. |
| `N8N_PROXY_HOPS` | `1` | not set | Number of trusted proxy hops in front of n8n (Traefik is one), so client IP and cookie handling are correct. |
| `N8N_SECURE_COOKIE` | `true` | `false` | Marks the session cookie secure. On over HTTPS in production; off for plain-HTTP local runs. |
| `GENERIC_TIMEZONE` | `UTC` | `UTC` | Timezone used by schedule and cron nodes. |
| `TZ` | not applicable | `UTC` | Standalone compose variable that feeds `GENERIC_TIMEZONE`. |
| `HTTP_PORT` | not applicable | `5678` | Host port published in standalone compose only (not published behind Traefik). |
| `N8N_IMAGE` | not applicable | `ghcr.io/remarkablecloud/n8n:2.38.6-r1` | Image reference override for standalone compose. |

## Hardening notes

- **Non-root by default.** The container runs as the `node` user, not root.
- **TLS at the proxy.** In production the container serves plain HTTP and Traefik terminates TLS. Keep the container off any public port and let the proxy reach it on the internal network.
- **Secure cookies on.** Set `N8N_SECURE_COOKIE=true` whenever n8n is served over HTTPS so session cookies are not sent over plain HTTP.
- **Trust exactly one proxy.** `N8N_PROXY_HOPS=1` matches a single Traefik hop. Raise it only if you add another trusted proxy in front.
- **Protect the instance.** Create the owner account immediately on first visit so the editor is not left open. Store secrets in n8n credentials rather than hard-coding them in nodes.
- **Healthcheck gating.** The `/healthz` healthcheck keeps a not-ready container out of rotation.

## Backup and upgrade

**Backup.** All state lives in the `n8n-data` volume at `/home/node/.n8n`: the SQLite database (workflows, executions, settings) and the credential encryption key. Back up the whole volume on a schedule. The encryption key is critical: if you lose it, every stored credential becomes unreadable even if you still have the database. For a consistent copy, snapshot the volume or stop the container briefly before copying.

**Upgrade.** Pull the newer RemarkableCloud tag (for example a later `-rN` or a new upstream version), then recreate the container. The named volume persists across the upgrade, so workflows and credentials carry over. Read the CHANGELOG for the target tag before upgrading, and back up the volume first. Because n8n uses SQLite here, an upgrade is a container swap with no separate database migration step to run.

## FAQ

**Does this image need an external database?**
No. It uses SQLite stored in the data volume. There is no separate database container to run.

**Can I run this behind Traefik or another reverse proxy?**
Yes. Terminate TLS at the proxy, forward to container port 5678, set `N8N_PROTOCOL=https`, `N8N_HOST`, `WEBHOOK_URL`, and `N8N_EDITOR_BASE_URL` to your public URL, and set `N8N_PROXY_HOPS` to the number of proxies in front.

**My webhooks return the wrong URL.**
Set `WEBHOOK_URL` (and `N8N_EDITOR_BASE_URL`) to your real public HTTPS URL. n8n builds webhook URLs from those values.

**Why is the container marked unhealthy at first?**
The healthcheck has a start period to let n8n initialize. It reports healthy once `/healthz` responds.

**Where is my data stored?**
In the `n8n-data` volume mounted at `/home/node/.n8n`, including the SQLite database and the encryption key.

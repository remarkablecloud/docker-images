---
title: "Self-Host Vaultwarden on Docker: Production Setup"
slug: "vaultwarden"
meta_description: "Self-host Vaultwarden (Bitwarden-compatible) with Docker Compose using the RemarkableCloud digest-pinned image: SQLite storage behind Traefik."
keywords:
  - vaultwarden docker
  - vaultwarden docker compose
  - self-hosted password manager
  - bitwarden self-hosted
  - vaultwarden traefik
  - vaultwarden sqlite backup
---

# Self-Host Vaultwarden with Docker

Vaultwarden is a lightweight, Bitwarden-compatible password manager server written in Rust. It speaks the Bitwarden API, so the official Bitwarden desktop, mobile, browser, and CLI clients connect to it directly, while it runs with a fraction of the resources of the full Bitwarden server stack. It stores everything in SQLite inside one data volume, so there is no external database to run.

This page covers the RemarkableCloud Vaultwarden image: what it adds over upstream, a full docker-compose walkthrough, an environment variable reference, and hardening, backup, and upgrade guidance for a production deployment.

## What the RemarkableCloud image adds

The RemarkableCloud image is a thin build on top of the upstream `vaultwarden/server` image (Vaultwarden 1.37.2, which runs as root). On top of that base it adds:

- **Digest-pinned base** for reproducible, auditable builds.
- **OCI provenance labels** (title, description, vendor, source) for supply-chain traceability.
- **Built-in healthcheck** against Vaultwarden's `/alive` endpoint, so an orchestrator only routes traffic to a ready instance.

The `1-r1` tag tracks the upstream 1.x line and is pinned by digest to the 1.37.2 release. Vaultwarden's own features are unchanged.

## docker-compose walkthrough

The image ships a standalone `docker-compose.yml`:

```yaml
name: vaultwarden

services:
  vaultwarden:
    image: ${VW_IMAGE:-ghcr.io/remarkablecloud/vaultwarden:1-r1}
    restart: unless-stopped
    ports: ["${HTTP_PORT:-8086}:80"]
    environment:
      DOMAIN: ${DOMAIN:-http://localhost:8086}
      SIGNUPS_ALLOWED: ${SIGNUPS_ALLOWED:-true}
    volumes:
      - vw-data:/data

volumes:
  vw-data:
```

Line by line:

- **image** pins the RemarkableCloud Vaultwarden tag, overridable with `VW_IMAGE`.
- **restart: unless-stopped** brings the container back after a crash or reboot.
- **ports** maps host port 8086 to container port 80. This is for standalone runs only. Behind Traefik, no port is published; the proxy routes to port 80 on the internal network.
- **DOMAIN** is the public URL of the server and must be exact (see the reference below).
- **SIGNUPS_ALLOWED** controls open registration.
- **volumes** mounts the `vw-data` volume at `/data`, which holds the SQLite database, attachments, RSA keys, and `config.json`.

Set your real URL and start it, for example `DOMAIN=https://vault.example.com docker compose up -d`. Open the URL, create your account, then close registration.

## Environment variable reference

| Variable | App Platform value | Standalone default | Notes |
|---|---|---|---|
| `DOMAIN` | `https://your-hostname` | `http://localhost:8086` | The exact public URL of the server. WebAuthn and two-factor authentication, attachment and Send links, and email links all depend on it being correct and using https in production. |
| `SIGNUPS_ALLOWED` | `true` | `true` | Whether new users can self-register. Set to `false` after you create your account. |
| `HTTP_PORT` | not applicable | `8086` | Host port mapped to container port 80 in standalone compose only (not published behind Traefik). |
| `VW_IMAGE` | not applicable | `ghcr.io/remarkablecloud/vaultwarden:1-r1` | Image reference override for standalone compose. |

## Hardening notes

- **Close registration.** The catalog ships with `SIGNUPS_ALLOWED=true` so you can create the first account. Set it to `false` immediately afterward so no one else can register. For controlled onboarding later, use Vaultwarden's invitation flow instead of reopening sign-ups.
- **Set DOMAIN correctly.** WebAuthn and two-factor authentication are bound to the exact origin. Use the real public https URL, with no trailing slash and no port.
- **TLS at the proxy.** In production the container serves plain HTTP on port 80 and Traefik terminates TLS. Keep the container off any public port and let the proxy reach it internally. Vaultwarden should always be reached over HTTPS.
- **Admin panel is off by default.** Vaultwarden's `/admin` panel stays disabled until you set an `ADMIN_TOKEN` environment variable (an upstream option). This image does not set one. If you enable it, use a long random token, ideally an Argon2 hash as documented upstream.
- **Runs as root.** The upstream server runs as root. Keep it isolated behind the proxy and do not publish its port.

## Backup and upgrade

**Backup.** All state lives in the `vw-data` volume at `/data`: the SQLite database (`db.sqlite3`), uploaded attachments, the RSA key files, and `config.json`. Back up the whole volume on a schedule. The RSA key files matter: keep them, or existing sessions and some tokens are invalidated after a restore. For a consistent database copy, either stop the container briefly before copying the volume, or run the SQLite backup API against the mounted database from the host or any container that has the `sqlite3` CLI (for example `sqlite3 db.sqlite3 ".backup 'backup.sqlite3'"`), so you never capture a database mid-write.

**Upgrade.** Pull the newer RemarkableCloud tag and recreate the container. The `vw-data` volume persists, so vaults, attachments, and keys carry over. Vaultwarden runs any needed schema migrations on start, and because it uses SQLite there is no separate database server to upgrade. Read the CHANGELOG for the target tag first, and back up the volume before upgrading.

## FAQ

**Which clients work with Vaultwarden?**
The official Bitwarden clients (desktop, mobile, browser extensions, and CLI) connect to Vaultwarden, since it implements the Bitwarden API. Point the client's server URL at your `DOMAIN`.

**Do I need an external database?**
No. Vaultwarden uses SQLite stored in the `/data` volume. There is no separate database container.

**How do I stop other people from registering?**
Set `SIGNUPS_ALLOWED=false` after creating your account. Add users later with Vaultwarden's invitation feature.

**Why must DOMAIN be exact?**
WebAuthn and two-factor authentication are tied to the exact origin, and attachment, Send, and email links are built from `DOMAIN`. A wrong value breaks those features.

**Where is my data stored?**
In the `vw-data` volume at `/data`: the SQLite database, attachments, RSA keys, and configuration.

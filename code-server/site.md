---
title: "Code Server on Docker (Production): the RemarkableCloud image"
slug: code-server
meta_description: "Run code-server (VS Code in the browser) on Docker in production: digest-pinned, non-root, healthchecked, with compose, env, hardening, and backup notes."
keywords:
  - code-server docker
  - code-server docker compose
  - vs code in browser self-hosted
  - code-server behind traefik
  - code-server production
  - self-hosted vs code
  - code-server reverse proxy
---

# Code Server on Docker, ready for production

Code Server runs a full Visual Studio Code in the browser, served from your own machine, so you can edit code, run a terminal, and use most VS Code extensions from any device. It gives a team a private, always-on development environment without shipping source to a third-party editor service. This page covers the RemarkableCloud Code Server image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy.

## What the RemarkableCloud image adds

The image is a production-oriented build of upstream `code-server` that keeps the official runtime and adds the packaging you would otherwise wire by hand:

- **Digest-pinned base.** Built from `codercom/code-server@sha256:57ac684d44deb6fa94317b3e8f3e128dd7fb897fffd95b4efcd16f56ce607971` (code-server 4.137.0 on Debian 13). Pinning by digest keeps rebuilds reproducible: the base changes only when we bump the digest on purpose.
- **Non-root by default.** The server runs as the unprivileged `coder` user (uid 1000), and the `/home/coder` volume is owned by that user so a mounted volume stays writable.
- **Password surfaced, never baked.** code-server generates a strong login password on first run and stores it in `config.yaml` inside the volume (so it is stable across restarts). Our entrypoint prints it once to the container log so it can be handed to the user. You can also pin your own with the `PASSWORD` variable. No credential is ever baked into an image layer.
- **Healthcheck.** A container `HEALTHCHECK` polls `/healthz` so the platform routes traffic only once the editor is up.

The current published tag is `ghcr.io/remarkablecloud/code-server:4.137.0-r1`.

code-server is a trademark of its respective owner. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **code-server** serves plain HTTP on port `8080`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform), so there is no in-container certificate to manage. WebSockets pass through the proxy for the live editor connection.
- **A data volume** at `/home/coder` holds settings, installed extensions, the `config.yaml` (with the login password), and your project files.
- No external database is required.

## Docker Compose walkthrough

The standalone stack is defined in the image's `docker-compose.yml`:

```yaml
name: code-server
services:
  code-server:
    image: ${CS_IMAGE:-ghcr.io/remarkablecloud/code-server:4.137.0-r1}
    restart: unless-stopped
    ports: ["${HTTP_PORT:-8443}:8080"]
    environment:
      PASSWORD: ${PASSWORD:-}
    volumes:
      - cs-data:/home/coder
volumes:
  cs-data:
```

Step by step:

1. **The image is pinned.** `CS_IMAGE` lets you override the tag for a local trial; the default is the published tag.
2. **Only the web port is exposed.** `${HTTP_PORT:-8443}:8080` is for local use. In production the reverse proxy connects to port `8080` on the internal network and nothing is bound on the host.
3. **Password is optional.** Leave `PASSWORD` empty to auto-generate one on first run (printed once to the log); set it to pin a known password.
4. **State lives in a volume.** `cs-data` (`/home/coder`) persists settings, extensions, `config.yaml`, and projects across restarts and upgrades.

To start it locally:

```
docker compose up -d
```

Then browse to `http://localhost:8443` and read the generated password from `docker compose logs`.

For production, put the container behind a TLS-terminating proxy and, if you want a known password, set `PASSWORD`.

## Environment variable reference

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `PASSWORD` | no | (generated) | Login password. Leave empty to auto-generate on first run (printed once to the log and stored in `config.yaml`); set it to pin your own. |

The App Platform deploys the catalog tag directly and does not use this compose file; the variable above applies to standalone and self-hosted runs.

## Hardening notes

- **Non-root runtime.** The editor and your shell run as uid 1000, not root.
- **No baked credentials.** The password is generated at runtime or supplied by you, never stored in an image layer.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/healthz` must return success before the platform routes requests.
- **Put it behind auth and TLS.** Always run behind the TLS-terminating proxy; the built-in password is the minimum, and the terminal inside code-server has the container's full access, so treat access as you would shell access.

## Backups

The single volume holds everything stateful:

```
docker run --rm -v code-server_cs-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/code-server-home.tgz -C /data .
```

Keep your projects in version control (for example a Gitea or GitHub remote) as the primary safety net; the volume backup captures settings, extensions, and anything not yet committed. On the RemarkableCloud App Platform, volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container:
  ```
  docker compose pull code-server && docker compose up -d code-server
  ```
- **Settings and extensions persist** in the `/home/coder` volume across the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the upstream version, base image digest, and any behavior changes.

## FAQ

**Do I need a database?**
No. code-server stores its settings and your files on the `/home/coder` volume; there is no external database.

**Where does the login password come from?**
If you set `PASSWORD`, that value is used. If you leave it empty, code-server generates one on first run, stores it in `config.yaml` in the volume, and our entrypoint prints it once to the container log.

**How does HTTPS work if the container only serves HTTP on port 8080?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which also forwards the WebSocket connection the editor needs.

**Can I install extensions?**
Yes. Extensions install into the `/home/coder` volume and persist across restarts and upgrades. Availability depends on the Open VSX registry that code-server uses.

**Is the terminal a real shell?**
Yes, it is a shell inside the container as the `coder` user. Treat access to the editor as equivalent to shell access, and keep it behind authentication and TLS.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/code-server:4.137.0-r1`. Avoid moving tags so a redeploy cannot change the image under you.

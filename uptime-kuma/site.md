---
title: "Uptime Kuma on Docker: the RemarkableCloud image"
slug: uptime-kuma
meta_description: "Run Uptime Kuma in production with Docker Compose using the RemarkableCloud digest-pinned image: SQLite, persistent data volume, healthcheck kept."
keywords:
  - uptime kuma docker
  - uptime kuma docker compose
  - uptime kuma self hosted
  - uptime kuma status page
  - uptime kuma behind traefik
  - self hosted uptime monitoring
  - uptime kuma production
  - uptime kuma sqlite
---

# Uptime Kuma on Docker with the RemarkableCloud image

Uptime Kuma is a self-hosted monitoring tool. It checks whether your websites,
APIs, TCP ports, DNS records, and containers are up, records response times,
raises alerts through dozens of notification channels (email, Slack, Telegram,
webhooks, and more), and publishes public or private status pages. It is a
practical replacement for a paid monitoring service when you would rather keep
your checks and history on your own server.

This page documents the RemarkableCloud build of Uptime Kuma: what it is, how to
run it with Docker Compose, where its data lives, and how to keep it backed up
and up to date in production.

## What the RemarkableCloud image is

The RemarkableCloud image is a straight, digest-pinned rebuild of the official
`louislam/uptime-kuma` image. The benefit is a known-good, reproducible starting
point that fits the App Platform conventions, without changing how Uptime Kuma
itself behaves.

- **Digest-pinned base.** The build is
  `louislam/uptime-kuma@sha256:3d632903e6af34139a37f18055c4f1bfd9b7205ae1138f1e5e8940ddc1d176f9`
  (Uptime Kuma 1.x). Pinning by digest means every rebuild of the `1-r1` tag
  resolves to the exact same upstream layer, which is what makes CVE tracking in
  the [changelog](./CHANGELOG.md) meaningful.
- **Upstream healthcheck kept.** The image keeps the upstream `HEALTHCHECK`
  (`extra/healthcheck`) and the upstream startup command, so your orchestrator
  gets readiness signals with no extra wiring.
- **Provenance labels.** Standard OCI labels record the title, description,
  vendor, and source repository.

This is a retag, not a fork. Uptime Kuma's features, storage format, and
behavior are exactly upstream.

## Run it with Docker Compose

The bundled `docker-compose.yml` is intentionally small: one service, one named
volume, and the built-in SQLite database inside it.

```yaml
# RemarkableCloud Uptime Kuma - standalone. SQLite; /app/data volume. Set up the admin on first visit.
name: uptime-kuma
services:
  uptime-kuma:
    image: ${UK_IMAGE:-ghcr.io/remarkablecloud/uptime-kuma:1-r1}
    restart: unless-stopped
    ports: ["${HTTP_PORT:-3001}:3001"]
    volumes:
      - uk-data:/app/data
volumes:
  uk-data:
```

Walking through it:

- **`image`** pins the RemarkableCloud tag by default and lets you override it
  with `UK_IMAGE` for testing a newer build.
- **`restart: unless-stopped`** brings the monitor back after a host reboot or
  crash, which matters for a tool whose job is to always be watching.
- **`ports`** publishes the container's port 3001 on the host. In a standalone
  test that is `http://localhost:3001`. In production you leave this on an
  internal network and let the proxy reach 3001 directly.
- **`volumes`** keeps all state (the SQLite database, monitor definitions,
  history, and uploaded assets) under `/app/data` in the named `uk-data` volume.

Start it, then open the UI and create your admin account:

```
docker compose up -d
```

The first visit to `http://localhost:3001` shows a setup screen where you choose
the admin username and password. There is no generated password to look up,
because Uptime Kuma provisions the admin interactively on first use.

### Behind Traefik

In production the platform runs Uptime Kuma behind Traefik, which terminates
TLS. Point the proxy at container port 3001. Uptime Kuma does not need a base-URL
environment variable for normal use; it serves correctly from the hostname the
proxy forwards. If you enable a public status page, set its domain in the status
page settings inside the app.

## Environment variable reference

This image sets no application environment variables. The catalog defines none,
and the compose file exposes only two overrides:

| Variable | Compose default | Platform value (catalog) | Notes |
|---|---|---|---|
| `UK_IMAGE` | `ghcr.io/remarkablecloud/uptime-kuma:1-r1` | pinned by catalog | Image reference; override only to test a build. |
| `HTTP_PORT` | `3001` | n/a (proxy reaches 3001) | Host port published by compose, mapped to container 3001. |

Uptime Kuma is configured through its web UI rather than environment variables.
Monitors, notifications, status pages, and the admin account are all managed
in-app and stored in the `/app/data` volume.

## Hardening notes

- **Create the admin account immediately.** Until you complete the first-visit
  setup, the instance is unclaimed. Do the setup as soon as the container is
  reachable, ideally before it is exposed publicly, and choose a strong
  password.
- **Terminate TLS at the proxy.** Serve Uptime Kuma over HTTPS through Traefik
  and keep the raw port on an internal network. Do not expose port 3001 to the
  internet directly.
- **Enable two-factor authentication.** Uptime Kuma supports 2FA on the admin
  account; turn it on from the settings once you are logged in.
- **Scope status pages deliberately.** A public status page reveals which
  services you monitor and their state. Publish only what you intend to be
  public, and keep internal checks on private pages.
- **Guard notification secrets.** Notification integrations store tokens and
  webhook URLs in the database, so protect the `/app/data` volume and its
  backups the same way you would protect credentials.

## Backups

All state lives in the `/app/data` volume: the SQLite database
(`kuma.db`), monitor definitions, check history, and settings. Backing up that
volume backs up the whole instance.

For a consistent file-level backup, stop the container so the SQLite database is
not written mid-copy, archive the volume, then start it again:

```
docker compose stop uptime-kuma
docker run --rm -v uptime-kuma_uk-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/uptime-kuma-data.tgz -C /data .
docker compose start uptime-kuma
```

The volume archive is the reliable backup. The in-app export under
Settings, then Backup, is deprecated in the 1.x line and does not capture
everything, so treat it as a convenience rather than your primary backup. Test a
restore into a throwaway stack before you rely on any backup.

## Upgrades

Uptime Kuma migrates its own database at startup, so upgrading is a matter of
moving to a newer image tag.

1. Read the [changelog](./CHANGELOG.md) and the upstream release notes for the
   target version.
2. Back up the `/app/data` volume first (see above). Database migrations are
   one-way.
3. Pull the new tag, then recreate the container:
   ```
   docker compose pull
   docker compose up -d
   ```
4. Confirm the container reports healthy and check that your monitors resume.

Never downgrade after a migration has run without restoring from a pre-upgrade
backup.

## FAQ

**How do I create the admin account?**
Open the site on your first visit and fill in the setup form. Uptime Kuma
creates the admin interactively; there is no generated password in the logs.

**I forgot the admin password. How do I reset it?**
Uptime Kuma has a built-in reset flow: run
`docker compose exec uptime-kuma node extra/reset-password.js` and follow the
prompts, then restart the container.

**Which database does it use?**
The built-in SQLite database stored in `/app/data`. This image ships the
standalone SQLite workflow (`db_mode = none`), with no external database.

**Can I monitor internal services?**
Yes. If Uptime Kuma shares a Docker network with other containers, it can check
them by service name and internal port. Public status pages should still expose
only what you want to be public.

**Which version of Uptime Kuma is this?**
The 1.x line, pinned by digest. The exact minor version is fixed by the pinned
base digest recorded in the [changelog](./CHANGELOG.md).

**Is this image affiliated with the Uptime Kuma project?**
No. It is an independently built and maintained image that repackages the
official upstream image. It is not endorsed by the Uptime Kuma project.

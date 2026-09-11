---
title: "Mattermost on Docker (Production): the RemarkableCloud image"
slug: mattermost
meta_description: "Run Mattermost on Docker in production: Slack alternative on PostgreSQL, digest-pinned, generated admin, closed signup, with compose and backups."
keywords:
  - mattermost docker
  - mattermost docker compose
  - self-hosted slack alternative
  - mattermost postgresql
  - mattermost behind traefik
  - mattermost production
  - team messaging self-hosted
---

# Mattermost on Docker, ready for production

Mattermost is an open source team messaging and collaboration platform, a self-hosted alternative to Slack: channels, direct messages, file sharing, search, integrations, and a REST API, all on infrastructure you control. This page covers the RemarkableCloud Mattermost image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by PostgreSQL.

## What the RemarkableCloud image adds

The image is a production-oriented build of the upstream `mattermost/mattermost-team-edition` image that keeps the official runtime and adds turnkey, secured provisioning:

- **Digest-pinned base.** Built from `mattermost/mattermost-team-edition@sha256:8285b96eb412d89dd308e4c1ad9cc7f1a9dc9edcd798167b55bc35f1c7ee69d1` (Mattermost 11.10.1). Pinning by digest keeps rebuilds reproducible.
- **No public-first-admin.** Mattermost normally makes the first person to sign up the system administrator. Our image creates a system admin with a generated password on first boot (via `mmctl` over a local socket) and disables open sign-up and email sign-up, so a random visitor can neither claim the admin role nor self-register. The password is printed once to the container log.
- **PostgreSQL, auto-migrated.** The database connection is configured from `MM_SQLSETTINGS_*`; Mattermost runs its schema migrations on start.
- **Healthcheck.** The upstream image is distroless, so we add a small static busybox and a `HEALTHCHECK` on `/api/v4/system/ping`, so the platform routes traffic only once the server is up.

The current published tag is `ghcr.io/remarkablecloud/mattermost:11.10.1-r1`.

Mattermost is a trademark of Mattermost, Inc. RemarkableCloud packages the open source Team Edition and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **Mattermost** serves plain HTTP on port `8065`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform). Set `MM_SERVICESETTINGS_SITEURL` to the public HTTPS address.
- **PostgreSQL** is a separate database container and holds all messages, users, and configuration.
- **Data volumes** hold uploaded files (`/mattermost/data`), configuration (`/mattermost/config`), and plugins (`/mattermost/plugins`, `/mattermost/client/plugins`).

## Docker Compose walkthrough

The standalone stack (Mattermost and PostgreSQL) is defined in the image's `docker-compose.yml`:

```yaml
name: mattermost
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: mattermost
      POSTGRES_PASSWORD: ${DB_PASSWORD:-change-me-db}
      POSTGRES_DB: mattermost
    volumes: [db-data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mattermost"]
      interval: 10s
      timeout: 5s
      retries: 12
  mattermost:
    image: ${MM_IMAGE:-ghcr.io/remarkablecloud/mattermost:11.10.1-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8099}:8065"]
    environment:
      MM_SQLSETTINGS_DATASOURCE: postgres://mattermost:${DB_PASSWORD:-change-me-db}@db:5432/mattermost?sslmode=disable
      MM_SERVICESETTINGS_SITEURL: ${SITE_URL:-http://localhost:8099}
      MM_ADMIN_PASSWORD: ${MM_ADMIN_PASSWORD:-}
    volumes:
      - mm-data:/mattermost/data
      - mm-config:/mattermost/config
      - mm-plugins:/mattermost/plugins
      - mm-client-plugins:/mattermost/client/plugins
volumes:
  db-data:
  mm-data:
  mm-config:
  mm-plugins:
  mm-client-plugins:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against PostgreSQL.
2. **The admin is created for you.** On first boot the image creates a system admin with a generated password (or `MM_ADMIN_PASSWORD` if set) and logs it once; open sign-up stays disabled.
3. **Only the web port is exposed.** `${HTTP_PORT:-8099}:8065` is for local use; in production the proxy connects to port `8065` on the internal network.
4. **State lives in volumes.** The four Mattermost volumes plus `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8099` and read the admin login from `docker compose logs mattermost`. For production, set `MM_SERVICESETTINGS_SITEURL` to your HTTPS address and put the container behind a TLS-terminating reverse proxy.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed PostgreSQL; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `MM_SQLSETTINGS_DATASOURCE` | yes | `postgres://<user>:<pass>@<host>:5432/<db>?sslmode=disable` | PostgreSQL connection string. |
| `MM_SERVICESETTINGS_SITEURL` | yes | `https://<hostname>` | Public site URL used for links and CORS. |
| `MM_ADMIN_PASSWORD` | no | (generated) | Initial admin password. Leave empty to auto-generate on first run (printed once); set it to pin your own. |
| `MM_ADMIN_USERNAME` | no | `admin` | Initial admin username. |
| `MM_ADMIN_EMAIL` | no | `admin@example.com` | Initial admin email. |

The driver (`MM_SQLSETTINGS_DRIVERNAME=postgres`), local mode, and the closed-signup settings are baked into the image. Only the first boot creates the admin.

## Hardening notes

- **No public-first-admin.** The system admin is created by the image on first boot; open sign-up and email sign-up are disabled by default.
- **No baked credentials.** The admin password is generated at runtime or supplied by you, never stored in an image layer.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/api/v4/system/ping` must return success before the platform routes requests.
- **Keep PostgreSQL private.** Do not publish its port to the host or the internet.
- **After first login,** create your team, invite users (invitations work even with open sign-up off), and keep Mattermost updated.

## Backups

Capture the database and the data volume together:

1. **The PostgreSQL database:**
   ```
   docker compose exec db pg_dump -U mattermost mattermost > mattermost-db.sql
   ```
2. **The data volume** (`/mattermost/data`: uploaded files):
   ```
   docker run --rm -v mattermost_mm-data:/data -v "$PWD":/backup alpine \
     tar czf /backup/mattermost-data.tgz -C /data .
   ```

On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; Mattermost runs its database migrations on start:
  ```
  docker compose pull mattermost && docker compose up -d mattermost
  ```
- **Back up first,** and keep the database dump and the `/mattermost/data` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. Mattermost stores everything in PostgreSQL. The standalone compose file includes it.

**Who is the admin?**
The image creates a system admin with a generated password on first boot and prints the login once to the container log. Set `MM_ADMIN_PASSWORD` to pin it.

**Can other people sign up?**
Not by default: open sign-up and email sign-up are disabled, so the admin invites users. You can enable sign-up later in the System Console.

**How does HTTPS work if the container serves HTTP on 8065?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards to port `8065`. Set `MM_SERVICESETTINGS_SITEURL` to your HTTPS address.

**Can I use MySQL instead of PostgreSQL?**
Mattermost supports MySQL, but this image and the App Platform target PostgreSQL; the compose file and defaults assume Postgres.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/mattermost:11.10.1-r1`. Avoid moving tags so a redeploy cannot change the image under you.

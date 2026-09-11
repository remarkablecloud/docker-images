---
title: "Chatwoot on Docker (Production): the RemarkableCloud image"
slug: chatwoot
meta_description: "Run Chatwoot on Docker in production: open source live chat and shared inbox on PostgreSQL and Redis, digest-pinned, generated admin, with compose."
keywords:
  - chatwoot docker
  - chatwoot docker compose
  - self-hosted live chat
  - chatwoot postgresql redis
  - chatwoot behind traefik
  - open source customer support
  - zendesk intercom alternative
---

# Chatwoot on Docker, ready for production

Chatwoot is an open source customer engagement platform: live chat, a shared inbox for email and social channels, canned responses, automation, and reporting, a self-hosted alternative to Zendesk and Intercom. This page covers the RemarkableCloud Chatwoot image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by PostgreSQL and Redis.

## What the RemarkableCloud image adds

The image is a production-oriented build of the official `chatwoot/chatwoot` image that keeps the official runtime and adds turnkey provisioning and a safe admin model:

- **Digest-pinned base.** Built from `chatwoot/chatwoot:v4.17.1@sha256:2116d958b52380ff3a609ad6b58db4a673b7733c31897771955b25350499ef06`. Pinning by digest keeps rebuilds reproducible.
- **Web and worker in one container.** Chatwoot needs both a Puma web process and a Sidekiq background worker. The entrypoint runs and supervises both; if either exits, the container exits so the platform restarts it, rather than leaving a half-running instance.
- **No public-first-admin.** A fresh Chatwoot install shows an onboarding page where the first visitor becomes the super administrator. Our image instead creates a super administrator on first boot with a strong generated password (using Chatwoot's own account builder), clears the onboarding state, and disables self-registration, so a random visitor can never claim the admin role.
- **Automatic database preparation.** On first boot the entrypoint waits for PostgreSQL, loads the schema, seeds, and applies migrations; on later boots it applies any pending migrations, so the same image is also the upgrade path.
- **PostgreSQL and Redis.** Connections are configured from `POSTGRES_*`, `REDIS_URL`, and `REDIS_PASSWORD`.
- **Persistent state.** Uploads, the generated secrets, and the generated admin password live in the `/app/storage` volume.
- **Healthcheck.** A container `HEALTHCHECK` polls `/health` so the platform routes traffic only once Chatwoot is serving.

The current published tag is `ghcr.io/remarkablecloud/chatwoot:4.17.1-r1`.

Chatwoot is a trademark of its authors. RemarkableCloud packages the open source edition and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **Chatwoot** serves on port `3000` (Puma), with a Sidekiq worker in the same container. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform).
- **PostgreSQL** must carry the `vector` extension: Chatwoot's schema enables `vector` (along with `pg_trgm`, `pgcrypto`, and others), so a standard `postgres` image will fail to load the schema. Use a `pgvector/pgvector` image.
- **Redis** backs Sidekiq and Chatwoot's caches and online presence.
- **A data volume** at `/app/storage` holds uploads (ActiveStorage local), the generated `SECRET_KEY_BASE`, and the generated admin password.

## Docker Compose walkthrough

The standalone stack (Chatwoot, PostgreSQL/pgvector, and Redis) is defined in the image's `docker-compose.yml`:

```yaml
name: chatwoot
services:
  postgres:
    image: pgvector/pgvector:pg16
    restart: unless-stopped
    environment:
      POSTGRES_USER: chatwoot
      POSTGRES_PASSWORD: ${DB_PASSWORD:-change-me-db}
      POSTGRES_DB: chatwoot
    volumes: [pg-data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U chatwoot"]
      interval: 10s
      timeout: 5s
      retries: 12
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD:-change-me-redis}"]
    volumes: [redis-data:/data]
  chatwoot:
    image: ${CHATWOOT_IMAGE:-ghcr.io/remarkablecloud/chatwoot:4.17.1-r1}
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports: ["${HTTP_PORT:-3099}:3000"]
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_USERNAME: chatwoot
      POSTGRES_PASSWORD: ${DB_PASSWORD:-change-me-db}
      POSTGRES_DATABASE: chatwoot
      REDIS_URL: redis://:${REDIS_PASSWORD:-change-me-redis}@redis:6379
      REDIS_PASSWORD: ${REDIS_PASSWORD:-change-me-redis}
      FRONTEND_URL: ${SITE_URL:-http://localhost:3099}
    volumes:
      - storage:/app/storage
volumes:
  pg-data:
  redis-data:
  storage:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against PostgreSQL.
2. **PostgreSQL carries pgvector.** The `pgvector/pgvector` image provides the `vector` extension the schema requires.
3. **First boot prepares the database.** The entrypoint loads the schema, seeds, migrates, then creates the super administrator and prints the login once to the log.
4. **Only the web port is exposed.** `${HTTP_PORT:-3099}:3000` is for local use; in production the proxy connects to port `3000` on the internal network.
5. **State lives in volumes.** `storage` (`/app/storage`) plus the database and Redis volumes persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) REDIS_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

The first boot loads the schema and migrates (about two to three minutes). Read the admin login from `docker compose logs chatwoot`, then open `http://localhost:3099`.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed PostgreSQL and Redis; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `POSTGRES_HOST` | yes | `<db_host>` | PostgreSQL host. |
| `POSTGRES_PORT` | no | `5432` | PostgreSQL port. |
| `POSTGRES_DATABASE` | yes | `<db_name>` | Database name. |
| `POSTGRES_USERNAME` | yes | `<db_user>` | Database user (needs `CREATE EXTENSION`; the platform's user is a superuser). |
| `POSTGRES_PASSWORD` | yes | `<db_password>` | Database password. |
| `REDIS_URL` | yes | `redis://:<pw>@<host>:6379` | Redis connection URL. |
| `REDIS_PASSWORD` | no | `<redis_password>` | Redis password (read separately by Chatwoot). |
| `FRONTEND_URL` | yes | `https://<hostname>` | Public URL; also used for links and the default admin email. |

`SECRET_KEY_BASE` and the admin password are generated on first run and stored in the data volume; they are not environment variables.

## Hardening notes

- **No public-first-admin.** The super administrator is created by us on first boot, the onboarding page is closed, and `ENABLE_ACCOUNT_SIGNUP=false` prevents self-registration.
- **Strong generated admin password.** Meets Chatwoot's complexity policy (upper, lower, digit, and special character) and is stored only in the data volume.
- **Stable secrets.** `SECRET_KEY_BASE` is generated once and persisted, so sessions and encrypted columns survive restarts.
- **No baked credentials.** All secrets are generated at runtime and kept in the data volume.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/health` must return success before the platform routes requests.
- **Keep PostgreSQL and Redis private.** Do not publish their ports to the host or the internet.
- **Configure SMTP** (via Chatwoot's environment) if you want email notifications, invitations, and password resets to be delivered.

## Backups

Capture the database and the data volume together:

1. **The PostgreSQL database:**
   ```
   docker compose exec postgres pg_dump -U chatwoot chatwoot > chatwoot-db.sql
   ```
2. **The data volume** at `/app/storage` (uploads and generated secrets):
   ```
   docker run --rm -v chatwoot_storage:/data -v "$PWD":/backup alpine \
     tar czf /backup/chatwoot-storage.tgz -C /data .
   ```

On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; the entrypoint applies any pending migrations on start:
  ```
  docker compose pull chatwoot && docker compose up -d chatwoot
  ```
- **Back up first,** and keep the database dump and the `/app/storage` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need PostgreSQL and Redis?**
Yes. Chatwoot stores its data in PostgreSQL (with the `vector` extension) and uses Redis for background jobs and caching. The standalone compose file includes both.

**Why pgvector and not plain postgres?**
Chatwoot's schema enables the `vector` extension, so the schema load fails on a standard `postgres` image. A `pgvector/pgvector` image includes it.

**How do I get the admin login?**
The image creates a super administrator on first boot and prints the login and generated password once to the container log. Change the password after first login. The super administrator console is at `/super_admin`.

**Why are the web and worker in one container?**
Chatwoot needs both a Puma web process and a Sidekiq worker. The image runs and supervises both; if either stops, the container stops so the platform restarts it. This keeps a single deployable unit without leaving a half-running instance.

**How does HTTPS work if the container serves HTTP on 3000?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards to port `3000` on the internal network.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/chatwoot:4.17.1-r1`. Avoid moving tags so a redeploy cannot change the image under you.

---
title: "LiteLLM on Docker (Production): the RemarkableCloud image"
slug: litellm
meta_description: "Run LiteLLM on Docker in production: LLM gateway with an OpenAI-compatible API and admin UI, PostgreSQL, generated master key, with compose and backups."
keywords:
  - litellm docker
  - litellm docker compose
  - llm gateway self-hosted
  - litellm proxy postgresql
  - openai-compatible api gateway
  - litellm behind traefik
  - litellm admin ui
---

# LiteLLM on Docker, ready for production

LiteLLM is an open source LLM gateway: it exposes 100+ model providers (OpenAI, Anthropic, Azure, Bedrock, local models, and many more) behind a single OpenAI-compatible API, with an admin UI for managing models, virtual API keys, and spend limits. This page covers the RemarkableCloud LiteLLM image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by PostgreSQL.

## What the RemarkableCloud image adds

The image is a production-oriented build of the upstream `ghcr.io/berriai/litellm` image that keeps the official runtime and adds turnkey, secured provisioning:

- **Digest-pinned base.** Built from `ghcr.io/berriai/litellm@sha256:a3715fa7ad8387941ab697259bd2881d68931657247a41984f90fae6d11c62bf` (LiteLLM 1.100.1, Python 3.13). Pinning by digest keeps rebuilds reproducible.
- **Gated from first boot.** A master key is generated on first run, so both the API and the admin UI require authentication immediately; nothing is open by default. You can pin your own with `LITELLM_MASTER_KEY`.
- **Stable salt key.** LiteLLM encrypts the provider API keys it stores in the database with a salt key. We generate one on first run and persist it in the data volume, so it stays stable and stored keys remain readable across restarts and upgrades.
- **PostgreSQL, auto-migrated.** Prisma migrations run on start; models, virtual keys, and spend are managed in the database (no config file to maintain).
- **Healthcheck.** The upstream image ships no curl, so we use a python-based `HEALTHCHECK` on `/health/liveliness`.

The current published tag is `ghcr.io/remarkablecloud/litellm:1.100.1-r1`.

LiteLLM is a trademark of its respective owner. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **LiteLLM** serves the API and admin UI on port `4000`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform).
- **PostgreSQL** is a separate database container and holds models, virtual keys, and spend data.
- **A small data volume** at `/app/rc-data` holds the generated master key and salt key.
- **LLM providers** are external: you add your own provider API keys in the admin UI.

## Docker Compose walkthrough

The standalone stack (LiteLLM and PostgreSQL) is defined in the image's `docker-compose.yml`:

```yaml
name: litellm
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: ${DB_PASSWORD:-change-me-db}
      POSTGRES_DB: litellm
    volumes: [db-data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U litellm"]
      interval: 10s
      timeout: 5s
      retries: 12
  litellm:
    image: ${LITELLM_IMAGE:-ghcr.io/remarkablecloud/litellm:1.100.1-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-4000}:4000"]
    environment:
      DATABASE_URL: postgresql://litellm:${DB_PASSWORD:-change-me-db}@db:5432/litellm
      LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY:-}
    volumes:
      - litellm-data:/app/rc-data
volumes:
  db-data:
  litellm-data:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against PostgreSQL.
2. **The master key is generated if blank.** Leave `LITELLM_MASTER_KEY` empty and the image creates one on first run and logs it once; it is both the API bearer token and the `/ui` admin login (username `admin`).
3. **Migrations run automatically.** Prisma applies the schema to PostgreSQL on start.
4. **Only the app port is exposed.** `${HTTP_PORT:-4000}:4000` is for local use; in production the proxy connects to port `4000` on the internal network.
5. **State lives in volumes.** `litellm-data` (`/app/rc-data`, the keys) and `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then read the master key from `docker compose logs litellm`, open `http://localhost:4000/ui`, log in as `admin` with that key, and add your provider API keys and models.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed PostgreSQL; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `DATABASE_URL` | yes | `postgresql://<user>:<pass>@<host>:5432/<db>` | PostgreSQL connection (Prisma). |
| `LITELLM_MASTER_KEY` | no | (generated) | API bearer + admin UI password. Leave empty to auto-generate on first run (printed once); set it to pin your own. |
| `LITELLM_SALT_KEY` | no | (generated) | Encrypts provider keys stored in the DB. Auto-generated and persisted; keep it stable. |
| `UI_USERNAME` | no | `admin` | Admin UI login name. |

`STORE_MODEL_IN_DB=true` is baked in, so models are managed in the UI/database.

## Hardening notes

- **Gated by default.** The API and UI require the master key from first boot; there is no anonymous access.
- **Salt stays stable.** The key that encrypts stored provider credentials is generated once and persisted, so a restart never orphans your stored keys.
- **No baked credentials.** Master and salt keys are generated at runtime or supplied by you, never stored in an image layer.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Keep PostgreSQL private.** Do not publish its port to the host or the internet.
- **Rotate the master key** if it leaks (via `LITELLM_MASTER_KEY`); treat it as admin access.

## Backups

Capture the database and the data volume together:

1. **The PostgreSQL database:**
   ```
   docker compose exec db pg_dump -U litellm litellm > litellm-db.sql
   ```
2. **The data volume** at `/app/rc-data` (master + salt keys):
   ```
   docker run --rm -v litellm_litellm-data:/data -v "$PWD":/backup alpine \
     tar czf /backup/litellm-data.tgz -C /data .
   ```

Keep the salt key (in `/app/rc-data`) with the database backup: without the matching salt, the provider keys stored in the database cannot be decrypted. On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; Prisma runs any migrations it needs on start:
  ```
  docker compose pull litellm && docker compose up -d litellm
  ```
- **Back up first,** and keep the database dump and the `/app/rc-data` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. This image uses PostgreSQL for the admin UI, virtual keys, and spend tracking. The standalone compose file includes it.

**Where does the master key come from?**
If you set `LITELLM_MASTER_KEY`, that value is used. If you leave it empty, the image generates one on first run and prints it once to the container log; it is both the API bearer and the `/ui` login.

**Do I need my own LLM provider keys?**
Yes. LiteLLM is a gateway to external providers; add your OpenAI/Anthropic/etc. keys and models in the admin UI.

**How does HTTPS work if the container serves HTTP on 4000?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards to port `4000` on the internal network.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/litellm:1.100.1-r1`. Avoid moving tags so a redeploy cannot change the image under you.

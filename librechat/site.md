---
title: "LibreChat on Docker (Production): the RemarkableCloud image"
slug: librechat
meta_description: "Run LibreChat on Docker in production: multi-provider AI chat UI on MongoDB, digest-pinned, registration off, initial account, with compose and backups."
keywords:
  - librechat docker
  - librechat docker compose
  - self-hosted chatgpt
  - librechat mongodb
  - multi-provider ai chat
  - librechat behind traefik
  - self-hosted ai chat ui
---

# LibreChat on Docker, ready for production

LibreChat is a self-hosted, open source AI chat interface: a ChatGPT-style UI in front of many providers (OpenAI, Anthropic, Azure, Google, local models, and more), with conversation history, presets, and per-user API keys. This page covers the RemarkableCloud LibreChat image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by MongoDB.

## What the RemarkableCloud image adds

The image is a production-oriented build of the upstream `ghcr.io/danny-avila/librechat` image that keeps the official runtime and adds turnkey, secured provisioning:

- **Digest-pinned base.** Built from `ghcr.io/danny-avila/librechat@sha256:c5db3331b845e1f289f8d04c0c77936c4bbe372f76730a804abc1c37e44d23a9` (LibreChat 0.8.7, Node 24). Pinning by digest keeps rebuilds reproducible.
- **No open sign-up.** Registration is disabled and an initial account is created on first run (generated password, printed once to the log), so a random visitor cannot self-register and spend your LLM credits. You can pin the account with `RC_USER_EMAIL` / `RC_USER_PASSWORD`.
- **Persistent encryption keys.** LibreChat encrypts the provider API keys users store with `CREDS_KEY` / `CREDS_IV`; we generate these (and the JWT secrets) on first run and persist them in the data volume, so they stay stable and stored keys remain readable across restarts and upgrades.
- **Single-container friendly.** Search (Meilisearch) is off by default, so the app runs with just MongoDB.
- **Healthcheck.** The upstream image ships no curl, so we use a `HEALTHCHECK` on `/health` via wget.

The current published tag is `ghcr.io/remarkablecloud/librechat:0.8.7-r1`.

LibreChat is a trademark of its respective owner. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **LibreChat** serves the UI and API on port `3080`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform).
- **MongoDB** is a separate database container and holds users, conversations, and messages.
- **Data volumes** hold the generated secrets (`/app/rc-data`), uploaded files (`/app/uploads`), and images (`/app/client/public/images`).
- **LLM providers** are external: each user adds their own provider API key in the UI (encrypted at rest).

## Docker Compose walkthrough

The standalone stack (LibreChat and MongoDB) is defined in the image's `docker-compose.yml`:

```yaml
name: librechat
services:
  mongo:
    image: mongo:7
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: librechat
      MONGO_INITDB_ROOT_PASSWORD: ${DB_PASSWORD:-change-me-db}
    volumes: [mongo-data:/data/db]
  librechat:
    image: ${LIBRECHAT_IMAGE:-ghcr.io/remarkablecloud/librechat:0.8.7-r1}
    restart: unless-stopped
    depends_on: [mongo]
    ports: ["${HTTP_PORT:-3080}:3080"]
    environment:
      MONGO_URI: mongodb://librechat:${DB_PASSWORD:-change-me-db}@mongo:27017/LibreChat?authSource=admin
      RC_USER_EMAIL: ${RC_USER_EMAIL:-}
      RC_USER_PASSWORD: ${RC_USER_PASSWORD:-}
    volumes:
      - librechat-data:/app/rc-data
      - librechat-uploads:/app/uploads
      - librechat-images:/app/client/public/images
volumes:
  mongo-data:
  librechat-data:
  librechat-uploads:
  librechat-images:
```

Step by step:

1. **MongoDB holds all chat state.** The `authSource=admin` in the URI matches Mongo's root user.
2. **The initial account is created for you.** On first run the image creates an account (or uses `RC_USER_EMAIL`/`RC_USER_PASSWORD`) and logs the login once; open registration stays off.
3. **Only the app port is exposed.** `${HTTP_PORT:-3080}:3080` is for local use; in production the proxy connects to port `3080` on the internal network.
4. **State lives in volumes.** The three LibreChat volumes plus `mongo-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then read the login from `docker compose logs librechat`, open `http://localhost:3080`, sign in, and add your LLM provider API key in the UI.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed MongoDB; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `MONGO_URI` | yes | `mongodb://<user>:<pass>@<host>:27017/<db>?authSource=admin` | MongoDB connection. |
| `RC_USER_EMAIL` | no | `admin@example.com` | Initial account email. |
| `RC_USER_PASSWORD` | no | (generated) | Initial account password. Leave empty to auto-generate on first run (printed once). |
| `CREDS_KEY` / `CREDS_IV` | no | (generated) | Encrypt stored provider keys. Auto-generated and persisted; keep stable. |
| `JWT_SECRET` / `JWT_REFRESH_SECRET` | no | (generated) | Sign auth tokens. Auto-generated and persisted. |

`ALLOW_REGISTRATION=false` and `SEARCH=false` are baked into the image.

## Hardening notes

- **No self-registration.** Only the created account can sign in; enable registration later in the config if you want more users.
- **Stable encryption keys.** The keys that encrypt stored provider credentials are generated once and persisted, so a restart never orphans them.
- **No baked credentials.** All secrets are generated at runtime or supplied by you, never stored in an image layer.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Keep MongoDB private.** Do not publish its port to the host or the internet.

## Backups

Capture the database and the data volumes together:

1. **The MongoDB database:**
   ```
   docker compose exec mongo mongodump --username librechat --password "$DB_PASSWORD" \
     --authenticationDatabase admin --db LibreChat --archive > librechat-db.archive
   ```
2. **The data volumes** (secrets, uploads, images):
   ```
   for v in data uploads images; do
     docker run --rm -v librechat_librechat-$v:/data -v "$PWD":/backup alpine \
       tar czf /backup/librechat-$v.tgz -C /data .
   done
   ```

Keep the secrets volume (`/app/rc-data`) with the database backup: without the matching `CREDS_KEY`, stored provider keys cannot be decrypted. On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; LibreChat applies any database changes it needs on start:
  ```
  docker compose pull librechat && docker compose up -d librechat
  ```
- **Back up first,** and keep the database archive and the `/app/rc-data` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. LibreChat stores users, conversations, and messages in MongoDB. The standalone compose file includes it.

**How do I log in the first time?**
The initial account (email and generated password) is printed once to the container log on first run. Registration is off, so this is the account to sign in with.

**Do I need my own LLM key?**
Yes. LibreChat is a front end to external providers; each user adds their provider API key in the UI, stored encrypted.

**Can I add more users?**
Yes, deliberately: create them with the `create-user` script, or enable registration in the LibreChat config.

**How does HTTPS work if the container serves HTTP on 3080?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards to port `3080` on the internal network.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/librechat:0.8.7-r1`. Avoid moving tags so a redeploy cannot change the image under you.

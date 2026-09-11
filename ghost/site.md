---
title: "Ghost on Docker (Production): the RemarkableCloud hardened image"
slug: ghost
meta_description: "Run Ghost 6 on Docker in production: digest-pinned image, MySQL 8, Traefik reverse proxy, healthcheck, plus compose, env, backup and upgrade notes."
keywords:
  - ghost docker
  - ghost docker compose
  - ghost docker compose production
  - ghost docker mysql 8
  - ghost behind traefik
  - ghost hardened image
  - self-hosted ghost blog
  - ghost 6 docker
---

# Ghost on Docker, ready for production

Ghost is an open source publishing and newsletter platform used by blogs,
magazines, and independent creators. It is a modern content management system
built on Node.js, with a clean editor, native memberships and paid
subscriptions, email newsletters, and a full REST and Admin API. This page
covers the RemarkableCloud Ghost image: what it is, what our build adds on top
of upstream, and how to run it in production with Docker Compose behind a
reverse proxy.

## What the RemarkableCloud image adds

The RemarkableCloud image is a focused, production-oriented build of upstream
Ghost 6. It keeps the official runtime and adds the operational glue you would
otherwise assemble yourself:

- **Digest-pinned base.** The image is built from
  `ghost:alpine@sha256:04a47602872ead868582b04129e035673ea68324bc97c2ed4a181b7c142152b8`
  (Ghost 6.63.0, Node 22, Alpine). Pinning by digest keeps rebuilds
  reproducible: the base changes only when we bump the digest on purpose, never
  by accident on a redeploy.
- **Reverse-proxy-aware healthcheck.** A container `HEALTHCHECK` probes the
  Ghost admin-site API and sends `X-Forwarded-Proto: https`, so the check passes
  with a 200 instead of following Ghost's HTTP to HTTPS redirect. Your platform
  can hold traffic until Ghost is genuinely ready.
- **Env-driven configuration.** The `url` and every `database__*` setting come
  from environment variables, so one image runs unchanged from a laptop to
  production. Nothing environment-specific is baked in.
- **Immutable tags and a published changelog.** Tags follow
  `<version>-r<build>` and never move, and every build is recorded in the
  changelog that also feeds security notifications.

The current published tag is `ghcr.io/remarkablecloud/ghost:6.63.0-r2`.

Ghost is a trademark of its respective owner. RemarkableCloud packages the open
source project and is not affiliated with or endorsed by the Ghost Foundation.

## Architecture at a glance

- **Ghost** serves plain HTTP on port `2368`. TLS is terminated upstream by a
  reverse proxy (Traefik on the RemarkableCloud App Platform), so there is no
  in-container certificate to manage.
- **MySQL 8** is a separate database container. Ghost 6 requires MySQL 8, so
  SQLite and MariaDB are not supported for production use.
- **A content volume** at `/var/lib/ghost/content` holds themes, images, member
  data files, and settings that must survive a container replacement.

## Docker Compose walkthrough

The standalone stack (Ghost, MySQL 8, and two named volumes) is defined in the
image's `docker-compose.yml`:

```yaml
name: ghost

services:
  db:
    image: mysql:8
    restart: unless-stopped
    command: ["--mysql-native-password=ON"]
    environment:
      MYSQL_DATABASE: ghost
      MYSQL_USER: ghost
      MYSQL_PASSWORD: ${DB_PASSWORD:-change-me-db}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-change-me-root}
    volumes: [db-data:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-p${DB_ROOT_PASSWORD:-change-me-root}"]
      interval: 10s
      timeout: 5s
      retries: 15

  ghost:
    image: ${GHOST_IMAGE:-ghcr.io/remarkablecloud/ghost:6.63.0-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8083}:2368"]
    environment:
      url: ${GHOST_URL:-http://localhost:8083}
      NODE_ENV: production
      database__client: mysql
      database__connection__host: db
      database__connection__port: "3306"
      database__connection__user: ghost
      database__connection__password: ${DB_PASSWORD:-change-me-db}
      database__connection__database: ghost
    volumes:
      - ghost-content:/var/lib/ghost/content

volumes:
  db-data:
  ghost-content:
```

Step by step:

1. **The database starts first.** `depends_on` with
   `condition: service_healthy` means Ghost waits until MySQL answers
   `mysqladmin ping`, so the first boot does not race the database.
2. **Ghost pulls the pinned image.** The `GHOST_IMAGE` variable lets you
   override the tag for a local trial. The App Platform does not use this compose
   file; it deploys the catalog tag directly (currently `6.63.0-r2`). The compose
   default shown here is standalone-only.
3. **Ghost connects over the private network.** `database__connection__host: db`
   reaches the MySQL service by its Compose name; no database port is published
   to the host.
4. **Only the web port is exposed.** `${HTTP_PORT:-8083}:2368` maps the Ghost
   HTTP port for a local run. In production, Traefik connects to `2368` on the
   internal network and nothing is bound on the host.
5. **State lives in volumes.** `ghost-content` and `db-data` persist across
   restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8083` and finish setup at
`http://localhost:8083/ghost`.

For production, set `GHOST_URL` (or `url`) to your real HTTPS address, point the
`database__*` variables at your managed MySQL 8, and put the container behind a
TLS-terminating proxy. Set `url` to `https://your-domain` so Ghost generates
correct canonical links, feed URLs, and email links.

## Environment variable reference

These are the values the App Platform backend wires automatically from the
managed MySQL database (`{...}` placeholders are filled per install). They are
listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `url` | yes | `https://<hostname>` | Public base URL Ghost uses for links, feeds, and email. Set to your HTTPS domain in production. |
| `NODE_ENV` | yes | `production` | Runs Ghost in production mode. |
| `database__client` | yes | `mysql` | Database driver. Ghost 6 requires MySQL 8. |
| `database__connection__host` | yes | `<db_host>` | MySQL host (the `db` service in Compose). |
| `database__connection__port` | yes | `3306` | MySQL port. |
| `database__connection__user` | yes | `<db_user>` | MySQL user. |
| `database__connection__password` | yes | `<db_password>` | MySQL password. |
| `database__connection__database` | yes | `<db_name>` | MySQL database name. |

The bundled MySQL service in the standalone compose also reads
`MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, and `MYSQL_ROOT_PASSWORD`; use
a managed database in production and you can drop the `db` service entirely.

Mail (for member sign-in and newsletters) is configured with Ghost's standard
`mail__*` variables against your SMTP provider; it is not preset by this image.

## Hardening notes

- **No TLS or admin secrets in the image.** TLS terminates at the proxy, and
  every credential arrives through environment variables, so there is no baked
  default password and no certificate to leak.
- **Digest-pinned, minimal base.** The Alpine base keeps the attack surface
  small, and the pinned digest makes each build auditable and reproducible.
- **Healthcheck gates traffic.** Because the healthcheck understands the proxy
  protocol header, an unhealthy or half-started container is not sent live
  requests.
- **Restart policy.** `restart: unless-stopped` recovers the service after a
  crash or host reboot without masking a container that is failing its health
  probe.
- **Keep the database private.** Do not publish the MySQL port to the host or
  the internet; let Ghost reach it over the internal network only.
- **Front it with a WAF or rate limiting** at the proxy for the `/ghost` admin
  area, and consider IP allow-listing that path if only a few authors use it.

## Backups

Two things must be captured together for a restorable backup:

1. **The MySQL database** (all posts, members, and settings):
   ```
   docker compose exec db mysqldump -u root -p"$DB_ROOT_PASSWORD" ghost > ghost-db.sql
   ```
2. **The content volume** at `/var/lib/ghost/content` (themes, images, and
   uploaded files):
   ```
   docker run --rm -v ghost_ghost-content:/content -v "$PWD":/backup alpine \
     tar czf /backup/ghost-content.tgz -C /content .
   ```

Take both at the same time and store them off the host. On the RemarkableCloud
App Platform, database and volume backups are handled by the platform's backup
schedule.

## Upgrades

- **Minor and patch upgrades** arrive as new `-r` builds of the same or a newer
  Ghost version. Pull the new tag, recreate the container, and Ghost runs any
  database migrations on start:
  ```
  docker compose pull ghost && docker compose up -d ghost
  ```
- **Always back up first.** Migrations are one-way; keep the database dump and
  content archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the
  upstream version, base image digest, and any behavior or breaking changes, so
  you can review a change before applying it.
- **Major Ghost versions** can carry theme or Node requirements; check the entry
  before moving across a major line.

## FAQ

**Does this image include a database?**
No. Ghost 6 requires MySQL 8, which runs as a separate container or managed
service. The standalone compose file includes a MySQL 8 service for convenience.

**Can I use SQLite or MariaDB?**
Not for production. Ghost 6 supports MySQL 8 only. The image is configured for
MySQL through the `database__*` variables.

**How does HTTPS work if the container only serves HTTP?**
TLS is terminated at the reverse proxy (Traefik on the App Platform). Set `url`
to your `https://` domain so Ghost emits correct links, and the proxy forwards
`X-Forwarded-Proto: https`.

**Why does the healthcheck send an `X-Forwarded-Proto` header?**
When `url` is HTTPS, Ghost 301-redirects plain HTTP requests. The header tells
Ghost the original request was already HTTPS, so the internal probe gets a 200
and the platform can trust the health signal.

**Where is my data stored?**
Posts, members, and settings live in MySQL. Themes, images, and uploads live in
the content volume at `/var/lib/ghost/content`. Back up both together.

**How do I configure email newsletters?**
Set Ghost's standard `mail__*` variables for your SMTP provider. Bulk newsletter
sending typically uses a dedicated transactional email service.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/ghost:6.63.0-r2`. Avoid
moving tags so a redeploy cannot change the image under you.

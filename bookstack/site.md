---
title: "BookStack on Docker (Production): the RemarkableCloud image"
slug: bookstack
meta_description: "Run BookStack on Docker in production: digest-pinned, per-instance APP_KEY, rotated default admin, MariaDB, healthcheck, plus compose, env, backup notes."
keywords:
  - bookstack docker
  - bookstack docker compose
  - self-hosted wiki
  - bookstack behind traefik
  - bookstack mariadb
  - bookstack production
  - bookstack app_key
---

# BookStack on Docker, ready for production

BookStack is an open source wiki and documentation platform that organizes content into a familiar shelves, books, chapters, and pages structure, with a WYSIWYG editor, full-text search, and page-level permissions. This page covers the RemarkableCloud BookStack image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by MariaDB.

## What the RemarkableCloud image adds

The image is a production-oriented build of the upstream `linuxserver/bookstack` image that keeps the official runtime and adds the packaging you would otherwise wire by hand:

- **Digest-pinned base.** Built from `lscr.io/linuxserver/bookstack@sha256:ec33b8ad7ab57305462e73f2f9bd091a3828ac9f62e7eaa4f4fac592b9310303` (BookStack v26.05.4 on Alpine, PHP 8.5). Pinning by digest keeps rebuilds reproducible: the base changes only when we bump the digest on purpose.
- **Per-instance APP_KEY.** BookStack is a Laravel application and needs an encryption key (`APP_KEY`) that stays identical across restarts and is never shared between instances. On first boot the image generates a unique key, stores it in the `/config` volume, and puts it in the environment before the application starts. Nothing is baked into an image layer, and you can still pin your own with the `APP_KEY` variable.
- **No default credentials.** Upstream seeds a well-known admin account (`admin@admin.com` / `password`). Our image rotates that password to a strong generated one on first boot, before the instance is reachable, and prints the login once to the container log. You can pin the password with `RC_ADMIN_PASSWORD` and change the email with `RC_ADMIN_EMAIL`. The rotation runs exactly once, so a password you set later is never overwritten.
- **Healthcheck.** A container `HEALTHCHECK` polls `/status` (which also confirms database, cache, and session backends) so the platform routes traffic only once BookStack is fully serving.

The current published tag is `ghcr.io/remarkablecloud/bookstack:26.05.4-r1`.

BookStack is a trademark of its respective owner. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **BookStack (nginx and PHP)** serves plain HTTP on port `80`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform), so there is no in-container certificate to manage. Set `APP_URL` to the public HTTPS address and `APP_PROXIES` so BookStack trusts the proxy for the request scheme.
- **MariaDB** is a separate database container and holds pages, users, permissions, and revisions.
- **A data volume** at `/config` holds uploaded images and attachments, the generated `APP_KEY`, and other instance state.

## Docker Compose walkthrough

The standalone stack (BookStack and MariaDB) is defined in the image's `docker-compose.yml`:

```yaml
name: bookstack
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: bookstack
      MARIADB_USER: bookstack
      MARIADB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-change-me-root}
    volumes: [db-data:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 12
  bookstack:
    image: ${BOOKSTACK_IMAGE:-ghcr.io/remarkablecloud/bookstack:26.05.4-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8088}:80"]
    environment:
      APP_URL: ${APP_URL:-http://localhost:8088}
      APP_KEY: ${APP_KEY:-}
      APP_PROXIES: ${APP_PROXIES:-}
      RC_ADMIN_EMAIL: ${RC_ADMIN_EMAIL:-}
      RC_ADMIN_PASSWORD: ${RC_ADMIN_PASSWORD:-}
      DB_HOST: db
      DB_PORT: "3306"
      DB_DATABASE: bookstack
      DB_USERNAME: bookstack
      DB_PASSWORD: ${DB_PASSWORD:-change-me-db}
    volumes:
      - bookstack-config:/config
volumes:
  db-data:
  bookstack-config:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against MariaDB.
2. **The key is created once.** Leave `APP_KEY` empty and the image generates one on first boot and keeps it in the `/config` volume across restarts and upgrades.
3. **The default admin is rotated.** Leave `RC_ADMIN_PASSWORD` empty and the image replaces the upstream default password with a strong generated one and prints the login once; set it to pin a known password.
4. **Only the web port is exposed.** `${HTTP_PORT:-8088}:80` is for local use; in production the proxy connects to port `80` on the internal network and nothing is bound on the host.
5. **State lives in volumes.** `bookstack-config` (`/config`) and `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8088` and read the admin login from `docker compose logs bookstack`. For production, set `APP_URL` to your HTTPS address, set `APP_PROXIES` to trust the proxy, and put the container behind a TLS-terminating reverse proxy.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed MariaDB; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `APP_URL` | yes | `https://<hostname>` | Public base URL BookStack uses to generate links. |
| `APP_KEY` | no | (generated) | Laravel encryption key. Leave empty to generate and persist one on first boot; set it to pin your own. |
| `APP_PROXIES` | no | `*` | Reverse proxies BookStack trusts for the forwarded scheme. Use the proxy address, or `*` when only the proxy can reach the container. |
| `RC_ADMIN_EMAIL` | no | `admin@admin.com` | Email for the initial admin after rotation. |
| `RC_ADMIN_PASSWORD` | no | (generated) | Initial admin password. Leave empty to auto-generate on first boot (printed once to the log); set it to pin your own. |
| `DB_HOST` | yes | `<db_host>` | MariaDB host. |
| `DB_PORT` | yes | `3306` | MariaDB port. |
| `DB_DATABASE` | yes | `<db_name>` | Database name. |
| `DB_USERNAME` | yes | `<db_user>` | Database user. |
| `DB_PASSWORD` | yes | `<db_password>` | Database password. |

The admin rotation only touches the first boot; once it has run, account changes happen inside BookStack.

## Hardening notes

- **No baked credentials.** The `APP_KEY` and the admin password are generated at runtime or supplied by you, never stored in an image layer.
- **No default login exposure.** The upstream `admin@admin.com` / `password` account is rotated before the instance is reachable, so a fresh site cannot be entered with public default credentials.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/status` must return success before the platform routes requests.
- **Keep MariaDB private.** Do not publish its port to the host or the internet.
- **After first login,** review users and roles, keep BookStack updated, and enable multi-factor authentication for administrators.

## Backups

Capture the database and the data volume together:

1. **The MariaDB database:**
   ```
   docker compose exec db mariadb-dump -u root -p"$DB_ROOT_PASSWORD" bookstack > bookstack-db.sql
   ```
2. **The data volume** at `/config` (uploaded images, attachments, `APP_KEY`):
   ```
   docker run --rm -v bookstack_bookstack-config:/data -v "$PWD":/backup alpine \
     tar czf /backup/bookstack-config.tgz -C /data .
   ```

Keep the `APP_KEY` (in `/config`) with the database backup: without the matching key, encrypted values in the database cannot be read. On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; BookStack runs any database migrations it needs on start:
  ```
  docker compose pull bookstack && docker compose up -d bookstack
  ```
- **Back up first,** and keep the database dump and the `/config` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. BookStack stores pages, users, and permissions in MariaDB (or MySQL). The standalone compose file includes MariaDB.

**What is APP_KEY and why does it matter?**
It is BookStack's encryption key. It must stay the same across restarts, and it must differ between instances. The image generates one on first boot and keeps it in the `/config` volume, so this is handled for you; back it up with the database.

**What are the first admin credentials?**
The image rotates the upstream default and prints the login (email and generated password) once to the container log on first boot. Set `RC_ADMIN_PASSWORD` to pin a known password.

**How does HTTPS work if the container only serves HTTP on port 80?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards requests to BookStack on the internal network. Set `APP_URL` to the HTTPS address and `APP_PROXIES` so links and redirects use the correct scheme.

**Can I use MySQL instead of MariaDB?**
Yes. BookStack connects with the MySQL driver, which works with both MySQL 8 and MariaDB; point `DB_HOST` at your server.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/bookstack:26.05.4-r1`. Avoid moving tags so a redeploy cannot change the image under you.

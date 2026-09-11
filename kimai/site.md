---
title: "Kimai on Docker (Production): the RemarkableCloud image"
slug: kimai
meta_description: "Run Kimai on Docker in production: digest-pinned, env-driven install, generated admin, MariaDB, proxy-aware, with compose and backup notes."
keywords:
  - kimai docker
  - kimai docker compose
  - self-hosted time tracking
  - kimai behind traefik
  - kimai mariadb
  - kimai production
  - open source timesheet
---

# Kimai on Docker, ready for production

Kimai is an open source time-tracking application for freelancers and teams: timesheets, projects and activities, customers, rates, exports, and invoicing, with roles and a REST API. This page covers the RemarkableCloud Kimai image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by MariaDB.

## What the RemarkableCloud image adds

The image is a production-oriented build of the upstream `kimai/kimai2` (apache) image that keeps the official runtime and adds turnkey provisioning:

- **Digest-pinned base.** Built from `kimai/kimai2@sha256:d6747832bafc63b69f95d505471e43430f55f2e8a5ca19d094a166c5c2da2239` (Kimai 2.66.0, PHP 8.3, Apache, Debian 12). Pinning by digest keeps rebuilds reproducible.
- **Env-driven install.** On first start the upstream entrypoint waits for the database, runs migrations, and creates the admin. Our wrapper generates a strong admin password, persists it in the data volume, and prints the login once. You can pin your own with `ADMINPASS`.
- **Safe database URL.** The wrapper builds `DATABASE_URL` from separate host, port, name, user, and password variables, URL-encoding the password so special characters cannot break the connection string.
- **Persistent app secret.** The upstream entrypoint auto-generates a unique `APP_SECRET` and persists it in `var/data`, so it never runs with the public default and sessions stay valid across restarts.
- **Proxy-aware.** `TRUSTED_PROXIES` covers private networks, so Kimai honors `X-Forwarded-Proto` behind a TLS-terminating reverse proxy and generates correct https URLs.
- **Healthcheck.** A container `HEALTHCHECK` confirms the app responds so the platform routes traffic only once Kimai is serving.

The current published tag is `ghcr.io/remarkablecloud/kimai:2.66.0-r1`.

Kimai is a trademark of its respective owner. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **Kimai (Apache and PHP)** serves plain HTTP on port `8001`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform); with `TRUSTED_PROXIES` set, Kimai derives https URLs from the forwarded headers.
- **MariaDB** is a separate database container and holds all timesheets and configuration.
- **A data volume** at `/opt/kimai/var/data` holds the `APP_SECRET` and uploaded data. Application code stays in the image.

## Docker Compose walkthrough

The standalone stack (Kimai and MariaDB) is defined in the image's `docker-compose.yml`:

```yaml
name: kimai
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: kimai
      MARIADB_USER: kimai
      MARIADB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-change-me-root}
    volumes: [db-data:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 12
  kimai:
    image: ${KIMAI_IMAGE:-ghcr.io/remarkablecloud/kimai:2.66.0-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8098}:8001"]
    environment:
      KIMAI_DB_HOST: db
      KIMAI_DB_PORT: "3306"
      KIMAI_DB_NAME: kimai
      KIMAI_DB_USER: kimai
      KIMAI_DB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      ADMINMAIL: ${ADMINMAIL:-admin@example.com}
      ADMINPASS: ${ADMINPASS:-}
    volumes:
      - kimai-data:/opt/kimai/var/data
volumes:
  db-data:
  kimai-data:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race, and Kimai's entrypoint also waits for the connection.
2. **Install is env-driven.** The `KIMAI_DB_*` variables drive migrations and admin creation; no web wizard.
3. **The admin password is generated if blank.** Leave `ADMINPASS` empty and the image creates a strong one on first run and logs it once.
4. **The web port is 8001.** `${HTTP_PORT:-8098}:8001` maps it for local use; in production the proxy connects to port `8001` on the internal network.
5. **State lives in volumes.** `kimai-data` (`var/data`) and `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8098` and read the admin login from `docker compose logs kimai`. For production, put the container behind a TLS-terminating reverse proxy; Kimai derives the scheme from the forwarded headers.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed MariaDB; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `KIMAI_DB_HOST` | yes | `<db_host>` | MariaDB host. |
| `KIMAI_DB_PORT` | no | `3306` | MariaDB port. |
| `KIMAI_DB_NAME` | yes | `<db_name>` | Database name. |
| `KIMAI_DB_USER` | yes | `<db_user>` | Database user. |
| `KIMAI_DB_PASSWORD` | yes | `<db_password>` | Database password (URL-encoded into DATABASE_URL). |
| `ADMINMAIL` | no | `admin@example.com` | Admin email created at install. |
| `ADMINPASS` | no | (generated) | Admin password. Leave empty to auto-generate on first run (printed once); set it to pin your own. |

You can also pass a full `DATABASE_URL` directly instead of the parts. Only the first run reads the admin variables.

## Hardening notes

- **No default credentials.** The admin password is generated at first run or supplied by you, never baked into an image layer.
- **Unique, persistent APP_SECRET.** Generated on first run and kept in `var/data`, never the public default.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** The app must respond before the platform routes requests.
- **Keep MariaDB private.** Do not publish its port to the host or the internet.
- **After first login,** create per-user accounts, keep Kimai updated, and enable two-factor authentication.

## Backups

Capture the database and the data volume together:

1. **The MariaDB database:**
   ```
   docker compose exec db mariadb-dump -u root -p"$DB_ROOT_PASSWORD" kimai > kimai-db.sql
   ```
2. **The data volume** at `var/data` (`APP_SECRET` and uploaded data):
   ```
   docker run --rm -v kimai_kimai-data:/data -v "$PWD":/backup alpine \
     tar czf /backup/kimai-data.tgz -C /data .
   ```

Keep the `APP_SECRET` (in `var/data`) with the database backup. On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Because the application lives in the image and only `var/data` is persisted, pulling a new tag updates Kimai; migrations run on start:
  ```
  docker compose pull kimai && docker compose up -d kimai
  ```
- **Back up first,** and keep the database dump and the `var/data` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. Kimai stores timesheets and configuration in MariaDB (or MySQL). The standalone compose file includes MariaDB.

**Where does the admin password come from?**
If you set `ADMINPASS`, that value is used. If you leave it empty, the image generates a strong one on first run and prints it once to the container log.

**Why does the container listen on 8001?**
That is Kimai's default Apache port. Map it to any host port locally; in production the reverse proxy connects to `8001` on the internal network.

**How does HTTPS work if the container only serves HTTP?**
TLS is terminated at the reverse proxy (Traefik on the App Platform). With `TRUSTED_PROXIES` set, Kimai honors `X-Forwarded-Proto` and generates https URLs.

**Can I use MySQL instead of MariaDB?**
Yes. Kimai connects with the MySQL driver, which works with both MySQL 8 and MariaDB; point `KIMAI_DB_HOST` at your server.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/kimai:2.66.0-r1`. Avoid moving tags so a redeploy cannot change the image under you.

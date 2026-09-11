---
title: "Joomla on Docker (Production): the RemarkableCloud image"
slug: joomla
meta_description: "Run Joomla 5 on Docker in production: digest-pinned image with a headless install, MariaDB, healthcheck, plus compose, env, backup and upgrade notes."
keywords:
  - joomla docker
  - joomla docker compose
  - joomla 5 docker
  - joomla behind traefik
  - joomla mariadb
  - self-hosted joomla
  - joomla production
---

# Joomla on Docker, ready for production

Joomla is a mature open source content management system for building websites, portals, and online applications, with a large extension and template ecosystem. This page covers the RemarkableCloud Joomla image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by MariaDB.

## What the RemarkableCloud image adds

The image is a production-oriented build of upstream Joomla 5 (PHP 8.3, Apache) that keeps the official runtime and adds turnkey provisioning:

- **Digest-pinned base.** Built from `joomla:5-php8.3-apache@sha256:55a35a9e0025624a55752981f636512f0fc43632bfec860e6301b152043dcfb7` (Debian 13). Pinning by digest keeps rebuilds reproducible.
- **Headless install.** With the database and admin variables set, Joomla installs on first start with no web installer step, so the site is ready to use immediately.
- **Admin password generated, never baked.** If no admin password is supplied, the image generates a strong one on first install and prints it once to the container log to hand to the customer. No credential is stored in an image layer.
- **Healthcheck.** A container `HEALTHCHECK` polls `/` so the platform routes traffic only once Joomla is serving.

The current published tag is `ghcr.io/remarkablecloud/joomla:5-r1`.

Joomla is a trademark of Open Source Matters, Inc. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **Joomla (Apache and PHP)** serves plain HTTP on port `80`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform), so there is no in-container certificate to manage.
- **MariaDB** is a separate database container and holds all site content and configuration.
- **A data volume** at `/var/www/html` holds Joomla itself, `configuration.php`, extensions, templates, and uploaded media.

## Docker Compose walkthrough

The standalone stack (Joomla and MariaDB) is defined in the image's `docker-compose.yml`:

```yaml
name: joomla
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: joomla
      MARIADB_USER: joomla
      MARIADB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-change-me-root}
    volumes: [db-data:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 12
  joomla:
    image: ${JOOMLA_IMAGE:-ghcr.io/remarkablecloud/joomla:5-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8087}:80"]
    environment:
      JOOMLA_DB_TYPE: mysqli
      JOOMLA_DB_HOST: db
      JOOMLA_DB_NAME: joomla
      JOOMLA_DB_USER: joomla
      JOOMLA_DB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      JOOMLA_SITE_NAME: ${JOOMLA_SITE_NAME:-Joomla}
      JOOMLA_ADMIN_USER: ${JOOMLA_ADMIN_USER:-Administrator}
      JOOMLA_ADMIN_USERNAME: ${JOOMLA_ADMIN_USERNAME:-admin}
      JOOMLA_ADMIN_PASSWORD: ${JOOMLA_ADMIN_PASSWORD:-}
      JOOMLA_ADMIN_EMAIL: ${JOOMLA_ADMIN_EMAIL:-admin@example.com}
    volumes:
      - joomla-data:/var/www/html
volumes:
  db-data:
  joomla-data:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against MariaDB.
2. **Install is headless.** The `JOOMLA_DB_*` and `JOOMLA_ADMIN_*` variables let Joomla install on first start without the web wizard.
3. **The admin password is generated if blank.** Leave `JOOMLA_ADMIN_PASSWORD` empty and the image creates a strong one on first install and logs it once.
4. **Only the web port is exposed.** `${HTTP_PORT:-8087}:80` is for local use; in production the proxy connects to port `80` on the internal network.
5. **State lives in volumes.** `joomla-data` (`/var/www/html`) and `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8087` and read the generated admin password from `docker compose logs joomla`. Change it and the admin email after first login.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed MariaDB; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `JOOMLA_DB_TYPE` | yes | `mysqli` | Database driver. |
| `JOOMLA_DB_HOST` | yes | `<db_host>` | MariaDB host. |
| `JOOMLA_DB_NAME` | yes | `<db_name>` | Database name. |
| `JOOMLA_DB_USER` | yes | `<db_user>` | Database user. |
| `JOOMLA_DB_PASSWORD` | yes | `<db_password>` | Database password. |
| `JOOMLA_SITE_NAME` | no | `Joomla` | Site title. |
| `JOOMLA_ADMIN_USER` | yes | `Administrator` | Admin display name. |
| `JOOMLA_ADMIN_USERNAME` | yes | `admin` | Admin login. |
| `JOOMLA_ADMIN_PASSWORD` | no | (generated) | Admin password. Leave empty to auto-generate on first install; printed once to the log. |
| `JOOMLA_ADMIN_EMAIL` | yes | `admin@example.com` | Admin email. |

Only the first install reads these; once `configuration.php` exists they are ignored, and account changes happen inside Joomla.

## Hardening notes

- **No baked credentials.** The admin password is generated at first install or supplied by you, never stored in an image layer.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/` must return success before the platform routes requests.
- **Keep MariaDB private.** Do not publish its port to the host or the internet.
- **After install, review the security checklist.** Remove the default admin email, keep Joomla and all extensions updated, and enable two-factor authentication for administrators.

## Backups

Capture the database and the data volume together:

1. **The MariaDB database:**
   ```
   docker compose exec db mysqldump -u root -p"$DB_ROOT_PASSWORD" joomla > joomla-db.sql
   ```
2. **The data volume** at `/var/www/html` (config, extensions, templates, media):
   ```
   docker run --rm -v joomla_joomla-data:/data -v "$PWD":/backup alpine \
     tar czf /backup/joomla-data.tgz -C /data .
   ```

On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; Joomla runs any database migrations it needs on start:
  ```
  docker compose pull joomla && docker compose up -d joomla
  ```
- **Always back up first,** and keep the database dump and data archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.
- **Check extension compatibility** across major Joomla upgrades.

## FAQ

**Do I need a database?**
Yes. Joomla stores everything in MariaDB (or MySQL). The standalone compose file includes MariaDB.

**Where does the admin password come from?**
If you set `JOOMLA_ADMIN_PASSWORD`, that value is used. If you leave it empty, the image generates a strong one on first install and prints it once to the container log.

**Can I use MySQL instead of MariaDB?**
Yes. Joomla connects with the `mysqli` driver, which works with both MySQL 8 and MariaDB; point `JOOMLA_DB_HOST` at your server.

**How does HTTPS work if the container only serves HTTP on port 80?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards requests to Joomla on the internal network.

**Where is my content stored?**
Configuration and content live in MariaDB; extensions, templates, and media live in the `/var/www/html` volume. Back up both together.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/joomla:5-r1`. Avoid moving tags so a redeploy cannot change the image under you.

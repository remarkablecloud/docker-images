---
title: "Drupal on Docker (Production): the RemarkableCloud image"
slug: drupal
meta_description: "Run Drupal on Docker in production: digest-pinned, headless drush install, generated admin, MariaDB, proxy-aware, with compose and backup notes."
keywords:
  - drupal docker
  - drupal docker compose
  - self-hosted drupal
  - drupal behind traefik
  - drupal mariadb
  - drupal drush install
  - drupal production
---

# Drupal on Docker, ready for production

Drupal is a flexible open source content management system for building content-rich sites, portals, and web applications, with a strong taxonomy, fine-grained permissions, and a large module and theme ecosystem. This page covers the RemarkableCloud Drupal image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by MariaDB.

## What the RemarkableCloud image adds

The image is a production-oriented build of the official `drupal` image that keeps the official runtime and adds turnkey provisioning:

- **Digest-pinned base.** Built from `drupal@sha256:4249d58e94b052d5601499c7d1377433b5c9a8ad7b7b2d330368ce29181aca9c` (Drupal 11.4.6, PHP 8.5, Apache, Debian 13). Pinning by digest keeps rebuilds reproducible.
- **Headless install with drush.** We add `drush` and run a first-boot `drush site:install` from environment variables, so Drupal installs with no web installer step and is ready to use immediately.
- **Admin password generated, never baked.** If no password is supplied, the image generates a strong one on first install and prints it once to the container log. You can pin your own with `DRUPAL_ADMIN_PASSWORD`.
- **Proxy-aware.** The install writes `reverse_proxy` and `trusted_host_patterns` into `settings.php`, so Drupal generates correct HTTPS URLs and serves cleanly behind a TLS-terminating reverse proxy without redirect loops.
- **Retag-safe layout.** Drupal core, contrib modules, and vendor libraries live in the image; only `sites/default` (your `settings.php` and uploaded files) is persisted. Pulling a new image tag updates the platform without touching your content or database.
- **Healthcheck.** A static `/rc-health.txt`, served directly by Apache and independent of Drupal routing, backs the container `HEALTHCHECK` so the platform routes traffic only once Drupal is serving.

The current published tag is `ghcr.io/remarkablecloud/drupal:11.4.6-r1`.

Drupal is a registered trademark of Dries Buytaert. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **Drupal (Apache and PHP)** serves plain HTTP on port `80`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform). Set `DRUPAL_TRUSTED_HOST` to the public hostname so Drupal accepts requests for it.
- **MariaDB** is a separate database container and holds all content and configuration.
- **A data volume** at `/opt/drupal/web/sites/default` holds `settings.php` and uploaded files. Core and modules stay in the image.

## Docker Compose walkthrough

The standalone stack (Drupal and MariaDB) is defined in the image's `docker-compose.yml`:

```yaml
name: drupal
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: drupal
      MARIADB_USER: drupal
      MARIADB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-change-me-root}
    volumes: [db-data:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 12
  drupal:
    image: ${DRUPAL_IMAGE:-ghcr.io/remarkablecloud/drupal:11.4.6-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8097}:80"]
    environment:
      DRUPAL_DB_HOST: db
      DRUPAL_DB_PORT: "3306"
      DRUPAL_DB_NAME: drupal
      DRUPAL_DB_USER: drupal
      DRUPAL_DB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      DRUPAL_ADMIN_USER: ${DRUPAL_ADMIN_USER:-admin}
      DRUPAL_ADMIN_PASSWORD: ${DRUPAL_ADMIN_PASSWORD:-}
      DRUPAL_ADMIN_EMAIL: ${DRUPAL_ADMIN_EMAIL:-admin@example.com}
      DRUPAL_SITE_NAME: ${DRUPAL_SITE_NAME:-Drupal}
      DRUPAL_TRUSTED_HOST: ${DRUPAL_TRUSTED_HOST:-}
    volumes:
      - drupal-default:/opt/drupal/web/sites/default
volumes:
  db-data:
  drupal-default:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against MariaDB.
2. **Install is headless.** The `DRUPAL_DB_*` variables drive `drush site:install`; no web wizard.
3. **The admin password is generated if blank.** Leave `DRUPAL_ADMIN_PASSWORD` empty and the image creates a strong one on first install and logs it once.
4. **Only the web port is exposed.** `${HTTP_PORT:-8097}:80` is for local use; in production the proxy connects to port `80` on the internal network.
5. **State lives in volumes.** `drupal-default` (`sites/default`) and `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8097` and read the admin login from `docker compose logs drupal`. For production, set `DRUPAL_TRUSTED_HOST` to your public hostname and put the container behind a TLS-terminating reverse proxy.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed MariaDB; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `DRUPAL_DB_HOST` | yes | `<db_host>` | MariaDB host. |
| `DRUPAL_DB_PORT` | no | `3306` | MariaDB port. |
| `DRUPAL_DB_NAME` | yes | `<db_name>` | Database name. |
| `DRUPAL_DB_USER` | yes | `<db_user>` | Database user. |
| `DRUPAL_DB_PASSWORD` | yes | `<db_password>` | Database password. |
| `DRUPAL_TRUSTED_HOST` | no | `<hostname>` | Public hostname; written to `trusted_host_patterns`. |
| `DRUPAL_ADMIN_USER` | no | `admin` | Admin login created at install. |
| `DRUPAL_ADMIN_PASSWORD` | no | (generated) | Admin password. Leave empty to auto-generate on first install (printed once); set it to pin your own. |
| `DRUPAL_ADMIN_EMAIL` | no | `admin@example.com` | Admin email. |
| `DRUPAL_SITE_NAME` | no | `Drupal` | Site name. |

Only the first install reads these; afterwards changes happen inside Drupal.

## Hardening notes

- **No baked credentials.** The admin password is generated at first install or supplied by you, never stored in an image layer.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/rc-health.txt` must return success before the platform routes requests.
- **Trusted host patterns.** Set `DRUPAL_TRUSTED_HOST` so Drupal only answers for your hostname.
- **Keep MariaDB private.** Do not publish its port to the host or the internet.
- **After install,** review roles and permissions, keep Drupal and modules updated, and consider making `settings.php` read-only.

## Backups

Capture the database and the data volume together:

1. **The MariaDB database:**
   ```
   docker compose exec db mariadb-dump -u root -p"$DB_ROOT_PASSWORD" drupal > drupal-db.sql
   ```
2. **The data volume** at `sites/default` (`settings.php` and uploaded files):
   ```
   docker run --rm -v drupal_drupal-default:/data -v "$PWD":/backup alpine \
     tar czf /backup/drupal-default.tgz -C /data .
   ```

On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Because core and modules live in the image and only `sites/default` is persisted, pulling a new tag updates Drupal core and modules; Drupal runs any database updates it needs:
  ```
  docker compose pull drupal && docker compose up -d drupal
  # then run database updates:
  docker compose exec drupal drush --root=/opt/drupal/web updatedb -y
  ```
- **Manage modules with composer** (an image rebuild), rather than the UI, so retag upgrades stay clean.
- **Back up first,** and keep the database dump and the `sites/default` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. Drupal stores content and configuration in MariaDB (or MySQL). The standalone compose file includes MariaDB.

**Where does the admin password come from?**
If you set `DRUPAL_ADMIN_PASSWORD`, that value is used. If you leave it empty, the image generates a strong one on first install and prints it once to the container log.

**How does HTTPS work if the container only serves HTTP on port 80?**
TLS is terminated at the reverse proxy (Traefik on the App Platform). The image sets `reverse_proxy` in `settings.php`, so Drupal honors `X-Forwarded-Proto` and generates https URLs. Set `DRUPAL_TRUSTED_HOST` to your hostname.

**Can I add modules?**
Yes, via composer as part of an image build, which keeps the retag-safe layout. UI-installed modules would live outside the persisted volume and be lost on a retag.

**Can I use MySQL instead of MariaDB?**
Yes. Drupal connects with the MySQL driver, which works with both MySQL 8 and MariaDB; point `DRUPAL_DB_HOST` at your server.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/drupal:11.4.6-r1`. Avoid moving tags so a redeploy cannot change the image under you.

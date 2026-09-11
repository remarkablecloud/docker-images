---
title: "EspoCRM on Docker (Production): the RemarkableCloud image"
slug: espocrm
meta_description: "Run EspoCRM on Docker in production: digest-pinned, headless install, generated admin, MariaDB, in-container job daemon, plus compose and backup notes."
keywords:
  - espocrm docker
  - espocrm docker compose
  - self-hosted crm
  - espocrm behind traefik
  - espocrm mariadb
  - espocrm production
  - open source crm docker
---

# EspoCRM on Docker, ready for production

EspoCRM is an open source customer relationship management platform for tracking contacts, leads, opportunities, cases, and email, with custom entities, workflows, and reporting. This page covers the RemarkableCloud EspoCRM image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by MariaDB.

## What the RemarkableCloud image adds

The image is a production-oriented build of the upstream `espocrm/espocrm` image that keeps the official runtime and adds turnkey provisioning:

- **Digest-pinned base.** Built from `espocrm/espocrm@sha256:817f2b063de2c9dc2655fedbf1960af33c9b04e84d61a4b95f243e8e9189de69` (EspoCRM 10.0.8, PHP 8.4, Apache, Debian 13). Pinning by digest keeps rebuilds reproducible.
- **Headless install.** With the database and site variables set, EspoCRM installs on first start with no web installer step, so the CRM is ready to use immediately.
- **No default credentials.** Upstream installs an `admin` / `password` account. Our image sets a strong generated password before the install runs, keeps it in the data volume so an install retry is consistent, and prints the login once to the container log. You can pin your own with `ESPOCRM_ADMIN_PASSWORD`, which is honoured and never logged.
- **Job daemon in the container.** EspoCRM needs a background daemon for scheduled jobs, inbound email, workflows, and notifications; upstream runs it as a separate container. Our image supervises it alongside the web server, so a single container is fully functional.
- **Retag-safe volumes.** Only `data/`, `custom/`, and `client/custom/` are persisted, so pulling a new image tag upgrades the core application code without wiping uploads or admin-built customizations.
- **Healthcheck.** A container `HEALTHCHECK` polls `/` so the platform routes traffic only once EspoCRM is serving.

The current published tag is `ghcr.io/remarkablecloud/espocrm:10.0.8-r1`.

EspoCRM is a trademark of its respective owner. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **EspoCRM (Apache and PHP)** serves plain HTTP on port `80`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform), so there is no in-container certificate to manage. Set `ESPOCRM_SITE_URL` to the public HTTPS address so links are generated correctly.
- **MariaDB** is a separate database container and holds all CRM records and configuration.
- **Data volumes** hold uploads and generated config (`data/`), backend customizations (`custom/`), and frontend customizations (`client/custom/`).
- **The job daemon** runs inside the container next to the web server.

## Docker Compose walkthrough

The standalone stack (EspoCRM and MariaDB) is defined in the image's `docker-compose.yml`:

```yaml
name: espocrm
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: espocrm
      MARIADB_USER: espocrm
      MARIADB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-change-me-root}
    volumes: [db-data:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 12
  espocrm:
    image: ${ESPOCRM_IMAGE:-ghcr.io/remarkablecloud/espocrm:10.0.8-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8091}:80"]
    environment:
      ESPOCRM_DATABASE_HOST: db
      ESPOCRM_DATABASE_PORT: "3306"
      ESPOCRM_DATABASE_NAME: espocrm
      ESPOCRM_DATABASE_USER: espocrm
      ESPOCRM_DATABASE_PASSWORD: ${DB_PASSWORD:-change-me-db}
      ESPOCRM_ADMIN_USERNAME: ${ESPOCRM_ADMIN_USERNAME:-admin}
      ESPOCRM_ADMIN_PASSWORD: ${ESPOCRM_ADMIN_PASSWORD:-}
      ESPOCRM_SITE_URL: ${ESPOCRM_SITE_URL:-http://localhost:8091}
    volumes:
      - espocrm-data:/var/www/html/data
      - espocrm-custom:/var/www/html/custom
      - espocrm-client-custom:/var/www/html/client/custom
volumes:
  db-data:
  espocrm-data:
  espocrm-custom:
  espocrm-client-custom:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against MariaDB.
2. **Install is headless.** The `ESPOCRM_DATABASE_*` and `ESPOCRM_SITE_URL` variables let EspoCRM install on first start without the web wizard.
3. **The admin password is generated if blank.** Leave `ESPOCRM_ADMIN_PASSWORD` empty and the image creates a strong one on first install and logs it once.
4. **Only the web port is exposed.** `${HTTP_PORT:-8091}:80` is for local use; in production the proxy connects to port `80` on the internal network.
5. **State lives in volumes.** The three EspoCRM volumes plus `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8091` and read the admin login from `docker compose logs espocrm`. For production, set `ESPOCRM_SITE_URL` to your HTTPS address and put the container behind a TLS-terminating proxy.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed MariaDB; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `ESPOCRM_DATABASE_HOST` | yes | `<db_host>` | MariaDB host. |
| `ESPOCRM_DATABASE_PORT` | no | `3306` | MariaDB port. |
| `ESPOCRM_DATABASE_NAME` | yes | `<db_name>` | Database name. |
| `ESPOCRM_DATABASE_USER` | yes | `<db_user>` | Database user. |
| `ESPOCRM_DATABASE_PASSWORD` | yes | `<db_password>` | Database password. |
| `ESPOCRM_SITE_URL` | yes | `https://<hostname>` | Public base URL used for link generation. |
| `ESPOCRM_ADMIN_USERNAME` | no | `admin` | Admin login created at install. |
| `ESPOCRM_ADMIN_PASSWORD` | no | (generated) | Admin password. Leave empty to auto-generate on first install (printed once); set it to pin your own. |

Only the first install reads the admin variables; once installed they are ignored, and account changes happen inside EspoCRM.

## Hardening notes

- **No default credentials.** The admin password is generated at first install or supplied by you, never left at the upstream default and never baked into an image layer.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/` must return success before the platform routes requests.
- **Keep MariaDB private.** Do not publish its port to the host or the internet.
- **After install,** review roles and teams, keep EspoCRM updated, and enable two-factor authentication for administrators.

## Backups

Capture the database and the data volumes together:

1. **The MariaDB database:**
   ```
   docker compose exec db mariadb-dump -u root -p"$DB_ROOT_PASSWORD" espocrm > espocrm-db.sql
   ```
2. **The data volumes** (uploads, config, and customizations):
   ```
   for v in data custom client-custom; do
     docker run --rm -v espocrm_espocrm-$v:/data -v "$PWD":/backup alpine \
       tar czf /backup/espocrm-$v.tgz -C /data .
   done
   ```

On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; EspoCRM runs any rebuild and migrations it needs on start:
  ```
  docker compose pull espocrm && docker compose up -d espocrm
  ```
- **Core code comes from the image, customizations from the volumes,** so a retag upgrades the application without wiping `custom/`, `client/custom/`, or uploads.
- **Back up first,** and keep the database dump and volume archives from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. EspoCRM stores everything in MariaDB (or MySQL). The standalone compose file includes MariaDB.

**Where does the admin password come from?**
If you set `ESPOCRM_ADMIN_PASSWORD`, that value is used. If you leave it empty, the image generates a strong one on first install and prints it once to the container log.

**Do scheduled jobs and inbound email work in a single container?**
Yes. The image runs EspoCRM's job daemon alongside the web server, so scheduled jobs, email fetching, workflows, and notifications run without a second container.

**How does HTTPS work if the container only serves HTTP on port 80?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards requests to EspoCRM on the internal network. Set `ESPOCRM_SITE_URL` to the HTTPS address so generated links use the correct scheme.

**Can I use MySQL instead of MariaDB?**
Yes. EspoCRM connects with the MySQL driver, which works with both MySQL 8 and MariaDB; point `ESPOCRM_DATABASE_HOST` at your server.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/espocrm:10.0.8-r1`. Avoid moving tags so a redeploy cannot change the image under you.

---
title: "Nextcloud on Docker (Production): the RemarkableCloud hardened image"
slug: nextcloud
meta_description: "Run Nextcloud 34 on Docker in production: hardened reverse-proxy image with MariaDB, Redis, healthcheck, plus compose, env, backup and upgrade notes."
keywords:
  - nextcloud docker
  - nextcloud docker compose
  - nextcloud docker hardened
  - nextcloud behind traefik
  - nextcloud mariadb redis
  - nextcloud reverse proxy
  - self-hosted nextcloud
  - nextcloud 34 docker
---

# Nextcloud on Docker, ready for production

Nextcloud is an open source platform for file sync and share, calendar,
contacts, notes, and real-time collaboration that you run on your own
infrastructure. It gives a team a private alternative to hosted file and office
suites, with desktop and mobile clients, document editing, and a large app
ecosystem. This page covers the RemarkableCloud Nextcloud image: what it is,
what our build adds on top of upstream, and how to run it in production with
Docker Compose behind a reverse proxy, backed by MariaDB and Redis.

## What the RemarkableCloud image adds

The RemarkableCloud image is a production-oriented build of upstream Nextcloud
34 (the `stable-apache` variant, so Apache and PHP run in one container). It
keeps the official runtime and adds the reverse-proxy and caching setup you
would otherwise wire by hand:

- **Digest-pinned base.** The image is built from
  `nextcloud:stable-apache@sha256:b97df9e0e1ee3c8c6cc009cb3f12ddce915d624d543b3bb93882025fe323a407`
  (Nextcloud 34.0.3). Pinning by digest keeps rebuilds reproducible: the base
  changes only when we bump the digest on purpose.
- **Reverse-proxy config baked in.** The image ships `overwriteprotocol=https`,
  a `trusted_proxies` list for the private container networks, and
  `overwritehost` plus `overwrite.cli.url` derived from `NC_OVERWRITE_HOST`. The
  hostname is read from the environment on each request, so canonical links,
  generated URLs, and background jobs follow the customer domain without being
  baked into the image. This avoids the classic "you are accessing this site
  from an untrusted domain" and mixed-content problems behind a proxy.
- **Redis and APCu caching wired.** Redis is used for the distributed cache and
  for file locking, and APCu is enabled for the fast local cache, which is the
  configuration Nextcloud recommends for a responsive multi-user instance.
- **PHP tuned.** OPcache is enabled and sized, and `expose_php` is turned off so
  the PHP version banner is not advertised.
- **Automatic first-run admin password.** On the first install, if no admin
  password is provided, the image generates a strong random password and prints
  it once to the container log to be handed to the customer. No default
  credential is ever baked in.
- **Healthcheck.** A container `HEALTHCHECK` polls `/status.php` so the platform
  routes traffic only once Nextcloud is up and its code is in place.

The current published tag is `ghcr.io/remarkablecloud/nextcloud:34.0.3-r1`.

Nextcloud is a trademark of its respective owner. RemarkableCloud packages the
open source project and is not affiliated with or endorsed by Nextcloud GmbH.

## Architecture at a glance

- **Nextcloud (Apache and PHP)** serves plain HTTP on port `80`. TLS is
  terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App
  Platform), so there is no in-container certificate to manage.
- **MariaDB** is a separate database container and holds all metadata (users,
  shares, file index, app data).
- **Redis** is a separate container used for the distributed cache and
  transactional file locking.
- **A data volume** at `/var/www/html` holds the Nextcloud code, the merged
  `config/`, apps, and user files that must survive a container replacement.

## Docker Compose walkthrough

The standalone stack (Nextcloud, MariaDB, Redis, and named volumes) is defined
in the image's `docker-compose.yml`:

```yaml
name: nextcloud

services:
  db:
    image: mariadb:11
    restart: unless-stopped
    command: ["--transaction-isolation=READ-COMMITTED", "--log-bin=binlog", "--binlog-format=ROW"]
    environment:
      MARIADB_DATABASE: nextcloud
      MARIADB_USER: nextcloud
      MARIADB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-change-me-root}
    volumes: [db-data:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 12

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD:-change-me-redis}"]

  app:
    image: ${NC_IMAGE:-ghcr.io/remarkablecloud/nextcloud:34.0.3-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8082}:80"]
    environment:
      MYSQL_HOST: db
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_PASSWORD: ${DB_PASSWORD:-change-me-db}
      REDIS_HOST: redis
      REDIS_HOST_PORT: "6379"
      REDIS_HOST_PASSWORD: ${REDIS_PASSWORD:-change-me-redis}
      NEXTCLOUD_ADMIN_USER: ${NEXTCLOUD_ADMIN_USER:-admin}
      NEXTCLOUD_ADMIN_PASSWORD: ${NEXTCLOUD_ADMIN_PASSWORD:-}
      NEXTCLOUD_TRUSTED_DOMAINS: ${NEXTCLOUD_TRUSTED_DOMAINS:-localhost}
      NC_OVERWRITE_HOST: ${NC_OVERWRITE_HOST:-}
    volumes:
      - nc-data:/var/www/html

volumes:
  db-data:
  nc-data:
```

Step by step:

1. **MariaDB is tuned for Nextcloud.** `READ-COMMITTED` isolation with row-based
   binary logging is the configuration Nextcloud recommends. The healthcheck
   waits until InnoDB is initialized.
2. **Redis requires a password.** The `redis` service starts with
   `--requirepass`, and the app connects with `REDIS_HOST_PASSWORD`, so the
   cache and lock store are not open on the network.
3. **The app waits for the database.** `depends_on` with
   `condition: service_healthy` avoids a first-boot race against MariaDB.
4. **The image is pinned.** `NC_IMAGE` lets you override the tag for a local
   trial. The App Platform does not use this compose file; it deploys the catalog
   tag directly (currently `34.0.3-r1`), which is also the compose default here.
5. **The admin password is generated if blank.** `NEXTCLOUD_ADMIN_PASSWORD` is
   left empty here, so the image creates one on first install and logs it once.
6. **Only the web port is exposed.** `${HTTP_PORT:-8082}:80` is for local use.
   In production Traefik connects to port `80` on the internal network and
   nothing is bound on the host.
7. **State lives in volumes.** `nc-data` (`/var/www/html`) and `db-data` persist
   across restarts and upgrades.

To start it locally:

```
REDIS_PASSWORD=$(openssl rand -hex 16) DB_PASSWORD=$(openssl rand -hex 16) \
  NEXTCLOUD_ADMIN_PASSWORD=$(openssl rand -hex 12) docker compose up -d
```

Then browse to `http://localhost:8082`. If you leave `NEXTCLOUD_ADMIN_PASSWORD`
unset, read the generated password from `docker compose logs app`.

For production, set `NC_OVERWRITE_HOST` and `NEXTCLOUD_TRUSTED_DOMAINS` to your
real domain, point the `MYSQL_*` and `REDIS_*` variables at your managed
services, and put the container behind a TLS-terminating proxy.

## Environment variable reference

These are the values the App Platform backend wires automatically from the
managed MariaDB and Redis (`{...}` placeholders are filled per install). They
are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `MYSQL_HOST` | yes | `<db_host>` | MariaDB host (the `db` service in Compose). |
| `MYSQL_DATABASE` | yes | `<db_name>` | Database name. |
| `MYSQL_USER` | yes | `<db_user>` | Database user. |
| `MYSQL_PASSWORD` | yes | `<db_password>` | Database password. |
| `REDIS_HOST` | yes | `<redis_host>` | Redis host for distributed cache and file locking. |
| `REDIS_HOST_PORT` | yes | `6379` | Redis port. |
| `REDIS_HOST_PASSWORD` | yes | `<redis_password>` | Redis password. |
| `NEXTCLOUD_ADMIN_USER` | yes | `admin` | Admin account created on first install. |
| `NEXTCLOUD_ADMIN_PASSWORD` | no | (generated) | Admin password. Leave empty to auto-generate on first run; the value is printed once to the container log. |
| `NEXTCLOUD_TRUSTED_DOMAINS` | yes | `<hostname>` | Domains Nextcloud will answer for. |
| `NC_OVERWRITE_HOST` | yes | `<hostname>` | Canonical host for links and CLI URLs behind the proxy. |

Only the first install reads `NEXTCLOUD_ADMIN_USER` and
`NEXTCLOUD_ADMIN_PASSWORD`; once `config/config.php` exists they are ignored, and
account changes happen inside Nextcloud.

## Hardening notes

- **No baked credentials.** The admin password is generated at runtime on first
  install and printed once to the log, never stored in an image layer.
- **Reverse-proxy trust is scoped.** `trusted_proxies` covers the private
  container ranges only, and `overwriteprotocol=https` ensures Nextcloud builds
  HTTPS links behind the proxy without trusting arbitrary forwarded headers.
- **PHP version hidden.** `expose_php=Off` removes the `X-Powered-By` banner.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/status.php` must return success before the
  platform routes requests.
- **Keep MariaDB and Redis private.** Do not publish their ports to the host or
  the internet; Redis is password-protected in the standalone stack.
- **After install, run the security checklist.** In Nextcloud's admin overview,
  clear any warnings (for example, add any missing recommended database indices
  with `occ`). For the background job mode, note that this stack has no cron
  sidecar; the default is AJAX, and switching to the recommended Cron mode
  requires a separate cron runner, which is not included here.

## Backups

Capture the database and the data volume together for a restorable backup:

1. **The MariaDB database:**
   ```
   docker compose exec db mysqldump -u root -p"$DB_ROOT_PASSWORD" nextcloud > nextcloud-db.sql
   ```
2. **The data volume** at `/var/www/html` (config, apps, and user files):
   ```
   docker run --rm -v nextcloud_nc-data:/data -v "$PWD":/backup alpine \
     tar czf /backup/nextcloud-data.tgz -C /data .
   ```

For a fully consistent copy of large instances, enable maintenance mode first
(`occ maintenance:mode --on`), back up, then turn it off. On the RemarkableCloud
App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **Nextcloud upgrades one major version at a time.** Do not skip a major
  release; move 34 to 35 to 36 in order, not straight to a later version.
- **New builds ship as new `-r` tags.** Pull the new tag and recreate the
  container; the upstream entrypoint runs the upgrade and any migrations on
  start:
  ```
  docker compose pull app && docker compose up -d app
  ```
- **Always back up first.** Keep the database dump and data archive from just
  before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the
  upstream version, base image digest, and any behavior or breaking changes.
- **Watch app compatibility.** Third-party apps may need updates or may be
  temporarily disabled across a major upgrade.

## FAQ

**Does this image include a database or Redis?**
No. MariaDB and Redis run as separate containers or managed services. The
standalone compose file includes both for convenience.

**Can I use MySQL instead of MariaDB?**
Yes, Nextcloud supports MySQL 8 as well; point the `MYSQL_*` variables at it. The
RemarkableCloud stack ships MariaDB by default.

**Where does the admin password come from?**
If you set `NEXTCLOUD_ADMIN_PASSWORD`, that value is used. If you leave it empty,
the image generates a strong random password on first install and prints it once
to the container log.

**How does HTTPS work if the container only serves HTTP on port 80?**
TLS is terminated at the reverse proxy (Traefik on the App Platform). The image
sets `overwriteprotocol=https` and trusts the private proxy network, so
Nextcloud builds correct HTTPS links.

**Why do I need Redis?**
Redis provides the distributed cache and transactional file locking, which keeps
a multi-user instance responsive and avoids file-locking errors. APCu handles
the fast local cache.

**Where is my data stored?**
Metadata lives in MariaDB; config, apps, and user files live in the data volume
at `/var/www/html`. Back up both together.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/nextcloud:34.0.3-r1`. Avoid
moving tags so a redeploy cannot change the image under you.

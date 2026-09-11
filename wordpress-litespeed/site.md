---
title: WordPress on LiteSpeed Enterprise (Docker)
slug: wordpress-litespeed-enterprise-docker
meta_description: "Run WordPress on LiteSpeed Web Server Enterprise with Docker: a hardened image with LiteSpeed Cache and Redis. Trial included; bring your own license."
keywords:
  - wordpress litespeed enterprise docker
  - wordpress docker hardened
  - wordpress lscache docker
  - litespeed web server wordpress image
  - wordpress redis object cache docker
  - wordpress docker compose production
  - litespeed byol docker
---

# WordPress on LiteSpeed Enterprise with Docker

RemarkableCloud packages WordPress on LiteSpeed Web Server Enterprise as a production-ready Docker
image, so you get the commercial LiteSpeed server and LiteSpeed Cache with caching, hardening, and
reverse-proxy behavior already configured. This page covers licensing, what the image contains, how to
run it with Docker Compose, every environment variable it reads, the hardening applied, and how to
handle backups and upgrades.

## What WordPress is

WordPress is the open-source content management system that powers a large share of the web. It runs
sites from personal blogs to business publications and online stores, using PHP for the application
and MySQL or MariaDB for storage. WordPress is extended through themes and plugins, which makes it
flexible, and it benefits from a caching layer and a tuned web server when it serves real traffic.

## Licensing (trial and bring your own license)

LiteSpeed Web Server Enterprise is commercial software, and this image ships with no license key:

- **Trial by default.** On first start the base auto-fetches a 14-day LiteSpeed trial key, which needs
  outbound internet. This is meant for evaluation.
- **Bring your own license for production.** Set `LSWS_SERIAL` to your LiteSpeed Enterprise serial.
  The entrypoint writes it to the server config before LiteSpeed starts, so your license activates
  instead of the trial. A trial cannot serve a production site past 14 days, so a serial is required
  for real use.
- **Third-party license.** This image requires a third-party LiteSpeed license. RemarkableCloud does
  not resell or include one.

If you want the same WordPress recipe without a commercial license, use the WordPress on OpenLiteSpeed
image, which is free and needs no serial.

## What our image adds

- **LiteSpeed Enterprise with PHP 8.4.** The base is `litespeedtech/litespeed`, pinned by digest for
  reproducible builds. It provides LiteSpeed Web Server Enterprise 6.3.6 with lsphp 8.4, LiteSpeed
  Cache, and HTTP/3.
- **Page cache and object cache wired in.** LiteSpeed Cache (full-page cache) and Redis Object Cache
  are pre-baked at build time and activated on first run. The docker vhost template has `.htaccess`
  auto-load enabled, so WordPress permalinks and LiteSpeed Cache rewrite rules take effect.
- **Proxy-aware canonical URLs.** The image serves plain HTTP on port 80 and reads `X-Forwarded-Proto`
  and `X-Forwarded-Host` to build `WP_HOME` and `WP_SITEURL` per request. Your real domain and HTTPS
  scheme come from the proxy, so nothing is baked into the image.
- **Hardened defaults.** Version banners are off in PHP, the in-dashboard file editor is disabled, and
  PHP workers run as a non-root user (details below).
- **Provisioning-gated healthcheck.** The container reports healthy only after WordPress is installed
  and serving, so an orchestrator does not route traffic to a half-built site.
- **Persistent content.** A named volume holds `wp-content` (uploads, installed plugins, and themes)
  and survives redeploys, while core and the baked plugins stay in the image.

## Docker Compose walkthrough

The recipe directory ships a `docker-compose.yml` that runs the full stack: the WordPress on LiteSpeed
Enterprise container, a MariaDB database, and a Redis cache. A trimmed version looks like this:

```yaml
name: wordpress-litespeed

services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: wordpress
      MARIADB_USER: wordpress
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
    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD:-change-me-redis}", "--save", "60", "1"]
    volumes: [redis-data:/data]

  wordpress:
    image: ghcr.io/remarkablecloud/wordpress-litespeed:6.3.6-r1
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8085}:80"]
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      REDIS_PASSWORD: ${REDIS_PASSWORD:-change-me-redis}
      WP_ADMIN_USER: ${WP_ADMIN_USER:-admin}
      WP_ADMIN_PASSWORD: ${WP_ADMIN_PASSWORD:-}
      WP_ADMIN_EMAIL: ${WP_ADMIN_EMAIL:-admin@example.com}
      WP_SITE_TITLE: ${WP_SITE_TITLE:-WordPress}
      # LSWS_SERIAL: your-litespeed-enterprise-serial   # omit to run on the trial license
    volumes:
      - wp-content:/var/www/vhosts/localhost/html/wp-content

volumes:
  db-data:
  redis-data:
  wp-content:
```

Start it with generated secrets:

```bash
REDIS_PASSWORD=$(openssl rand -hex 16) DB_PASSWORD=$(openssl rand -hex 16) \
WP_ADMIN_PASSWORD=$(openssl rand -hex 12) docker compose up -d
```

Then browse `http://localhost:8085`. The WordPress container stays unhealthy until provisioning is
finished, which takes a little longer than the web server coming up, so wait for `healthy` before you
send traffic. If you leave `WP_ADMIN_PASSWORD` unset, the provisioner generates one and prints it once
to the container log. For production, uncomment `LSWS_SERIAL` and set your license serial.

In production you place a TLS-terminating reverse proxy (such as Traefik) in front of the WordPress
service. The proxy handles certificates and HTTP/3 and forwards `X-Forwarded-Proto` and
`X-Forwarded-Host`, which the image uses to set the canonical site URL.

## Environment variable reference

The database and Redis variables are wired automatically by the RemarkableCloud App Platform from the
managed MariaDB and Redis. They are listed here for standalone runs. The `WP_*` first-run variables
are optional and used only when the site is first installed. `LSWS_SERIAL` is optional and controls
licensing.

| Variable | Required | Default | Description |
|---|---|---|---|
| `WORDPRESS_DB_HOST` | Yes | `127.0.0.1` | Database host, as `host` or `host:port`; port defaults to `3306`. |
| `WORDPRESS_DB_NAME` | Yes | `wordpress` | Database name. |
| `WORDPRESS_DB_USER` | Yes | `wordpress` | Database user. |
| `WORDPRESS_DB_PASSWORD` | Yes | (empty) | Database password. |
| `REDIS_HOST` | No | (unset) | Redis host; when set, the Redis object cache is enabled. |
| `REDIS_PORT` | No | `6379` | Redis port. |
| `REDIS_PASSWORD` | No | (unset) | Redis password; written as `WP_REDIS_PASSWORD` when present. |
| `LSWS_SERIAL` | No | (unset) | LiteSpeed Enterprise serial; omit to run on the 14-day trial. |
| `WP_ADMIN_USER` | No | `admin` | Admin username, created on first install only. |
| `WP_ADMIN_PASSWORD` | No | (generated) | Admin password; generated and printed to the log once if unset. |
| `WP_ADMIN_EMAIL` | No | `admin@example.com` | Admin email, used on first install only. |
| `WP_SITE_TITLE` | No | `WordPress` | Site title, used on first install only. |

Ports and volumes:

- **Port:** the container listens on `80` (plain HTTP). Map or proxy it as needed.
- **Volume:** `/var/www/vhosts/localhost/html/wp-content` holds uploads, plugins, and themes and
  should be persisted.
- **Health path:** `/rc-health.txt` returns a static `ok` and is used by the container healthcheck.

## Hardening notes

- **No version disclosure.** PHP has `expose_php` off. Error display is off while error logging stays
  on.
- **Locked-down WordPress.** The dashboard file editor is disabled (`DISALLOW_FILE_EDIT`), core
  auto-updates are limited to minor releases, and `WP_ENVIRONMENT_TYPE` is set to `production`.
- **Minimal exposure.** Only the HTTP port (`80`) is published; TLS terminates at the reverse proxy.
- **Non-root workers.** lsphp workers run as `nobody:nogroup` rather than root.

## Backups

Two things need backing up: the database and the `wp-content` volume.

```bash
# Database dump
docker compose exec db \
  sh -c 'mariadb-dump -u root -p"$MARIADB_ROOT_PASSWORD" wordpress' > wordpress-db.sql

# wp-content archive
docker run --rm -v wordpress-litespeed_wp-content:/data -v "$PWD":/backup alpine \
  tar czf /backup/wp-content.tgz -C /data .
```

Restore by importing the SQL dump into the `db` service and extracting the archive back into the
`wp-content` volume. Take backups on a schedule and keep copies off the host.

## Upgrades

- **WordPress core, themes, and plugins.** Update these from the WordPress dashboard or with wp-cli,
  for example `docker compose exec wordpress wp core update --allow-root`. These changes live in the
  database and the `wp-content` volume, so they persist across container restarts.
- **The image itself.** Pull a newer tag and recreate the container:
  `docker compose pull wordpress && docker compose up -d wordpress`. Because core and the baked
  plugins live in the image while your content lives in the volume, replacing the image updates the
  server and the baseline plugins without touching your uploads and installed extensions. Your
  `LSWS_SERIAL` is supplied through the environment, so it carries across upgrades. Review the
  `CHANGELOG.md` before upgrading, and take a backup first.
- **Pin by digest** in regulated environments so a rebuild of the same tag cannot change what you run.

## FAQ

**Do I need a LiteSpeed license?**
For evaluation, no: the image runs on a 14-day LiteSpeed trial out of the box. For production, yes:
set `LSWS_SERIAL` to your LiteSpeed Enterprise serial. This image requires a third-party LiteSpeed
license, which RemarkableCloud does not include or resell.

**How is this different from the OpenLiteSpeed image?**
It uses the same WordPress recipe (LiteSpeed Cache and a Redis object cache, proxy-aware URLs, the same
provisioner) on the commercial LiteSpeed Enterprise server rather than the free OpenLiteSpeed server.
Choose OpenLiteSpeed if you do not want a commercial license.

**Does this include a database or Redis?**
No. The image is the web server and WordPress only. The database and Redis run as separate services,
as shown in the Compose file.

**Do I need to configure TLS inside the container?**
No. The image serves plain HTTP on port 80 and expects a reverse proxy to terminate TLS. It reads the
forwarded headers to set the correct HTTPS canonical URL.

**Why is the container unhealthy for the first minute or two?**
The healthcheck is intentionally gated on a provisioning marker. It reports healthy only after
WordPress is installed and serving, so traffic is never routed to a half-built site.

**Where do I find the exact bundled plugin versions?**
They are recorded in `wp-content/.rc-plugins` inside the image and summarized in the `CHANGELOG.md`
for each build.

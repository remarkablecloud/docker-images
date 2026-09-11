---
title: "WooCommerce on Docker (Production): the RemarkableCloud image"
slug: woocommerce
meta_description: "Run WooCommerce on Docker in production: on OpenLiteSpeed with LiteSpeed Cache, Redis object cache, MariaDB, healthcheck, plus compose and backups."
keywords:
  - woocommerce docker
  - woocommerce docker compose
  - self-hosted online store
  - woocommerce openlitespeed
  - woocommerce behind traefik
  - woocommerce redis cache
  - woocommerce production
---

# WooCommerce on Docker, ready for production

WooCommerce turns WordPress into a full online store: a product catalog, cart and checkout, orders, payments, shipping, and tax, extendable with themes and thousands of extensions. This page covers the RemarkableCloud WooCommerce image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by MariaDB and a Redis object cache.

## What the RemarkableCloud image adds

The image is a preset built on our own hardened WordPress + OpenLiteSpeed image, with WooCommerce packaged in:

- **Built on our WordPress + OpenLiteSpeed image.** Derived from `ghcr.io/remarkablecloud/wordpress-ols:7.1-r2` (WordPress on OpenLiteSpeed, PHP 8.5), so it inherits LiteSpeed Cache, a Redis object cache, proxy-aware canonical URLs, non-root PHP workers, and hardened defaults.
- **WooCommerce baked in and auto-activated.** WooCommerce 11.1.0 is baked into the image at build time and activated on first run, before the readiness marker is set, so the store's pages and database tables are created and the site is not routed to until it is fully set up.
- **Admin password generated on first run.** If no password is supplied, a strong one is generated on first install and printed once to the container log. No credential is baked into an image layer.
- **Provisioned-readiness healthcheck.** The container `HEALTHCHECK` stays unhealthy until provisioning finishes, then polls a static `/rc-health.txt` served directly by OpenLiteSpeed (never PHP-rendered or page-cached), so the platform never routes to a half-set-up store or primes the page cache with a wrong canonical URL.

The current published tag is `ghcr.io/remarkablecloud/woocommerce:11.1.0-r1`.

WooCommerce and WordPress are trademarks of their respective owners. RemarkableCloud packages the open source projects and is not affiliated with or endorsed by the upstream projects.

## Architecture at a glance

- **WooCommerce (WordPress on OpenLiteSpeed)** serves plain HTTP on port `80`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform); the image derives the canonical URL from the `X-Forwarded-Proto` and `X-Forwarded-Host` headers, so links and checkout use HTTPS.
- **MariaDB** is a separate database container and holds products, orders, customers, and settings.
- **Redis** is a separate container used for the WordPress object cache.
- **A data volume** at `wp-content` holds uploads and installed plugins and themes. WordPress core, WooCommerce, and our baked plugins live in the image and are seeded into an empty volume on first mount.

## Docker Compose walkthrough

The standalone stack (WooCommerce, MariaDB, and Redis) is defined in the image's `docker-compose.yml`:

```yaml
name: woocommerce
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: woocommerce
      MARIADB_USER: woocommerce
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
  woocommerce:
    image: ${WOO_IMAGE:-ghcr.io/remarkablecloud/woocommerce:11.1.0-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8092}:80"]
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: woocommerce
      WORDPRESS_DB_USER: woocommerce
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      REDIS_PASSWORD: ${REDIS_PASSWORD:-change-me-redis}
      WP_ADMIN_USER: ${WP_ADMIN_USER:-admin}
      WP_ADMIN_PASSWORD: ${WP_ADMIN_PASSWORD:-}
      WP_ADMIN_EMAIL: ${WP_ADMIN_EMAIL:-admin@example.com}
      WP_SITE_TITLE: ${WP_SITE_TITLE:-Store}
    volumes:
      - wp-content:/var/www/vhosts/wordpress/html/wp-content
volumes:
  db-data:
  redis-data:
  wp-content:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against MariaDB.
2. **First boot provisions the store.** WordPress core installs, WooCommerce and the cache plugins activate, and WooCommerce creates its pages and tables, all before the container reports healthy.
3. **The admin password is generated if blank.** Leave `WP_ADMIN_PASSWORD` empty and the image creates a strong one on first run and logs it once.
4. **Only the web port is exposed.** `${HTTP_PORT:-8092}:80` is for local use; in production the proxy connects to port `80` on the internal network.
5. **State lives in volumes.** `wp-content`, `db-data`, and `redis-data` persist across restarts and upgrades.

To start it locally:

```
REDIS_PASSWORD=$(openssl rand -hex 16) DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8092` and read the admin login from `docker compose logs woocommerce`. For production, put the container behind a TLS-terminating reverse proxy; the canonical URL follows the forwarded headers automatically.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed MariaDB and Redis; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `WORDPRESS_DB_HOST` | yes | `<db_host>:<db_port>` | MariaDB host and port. |
| `WORDPRESS_DB_NAME` | yes | `<db_name>` | Database name. |
| `WORDPRESS_DB_USER` | yes | `<db_user>` | Database user. |
| `WORDPRESS_DB_PASSWORD` | yes | `<db_password>` | Database password. |
| `REDIS_HOST` | no | `<redis_host>` | Redis host for the object cache. Unset disables it. |
| `REDIS_PORT` | no | `6379` | Redis port. |
| `REDIS_PASSWORD` | no | `<redis_password>` | Redis password (Coolify-managed Redis sets one). |
| `WP_ADMIN_USER` | no | `admin` | Admin login created at install. |
| `WP_ADMIN_PASSWORD` | no | (generated) | Admin password. Leave empty to auto-generate on first run (printed once); set it to pin your own. |
| `WP_ADMIN_EMAIL` | no | `admin@example.com` | Admin email. |
| `WP_SITE_TITLE` | no | `Store` | Site title. |

Only the first run reads the admin and site variables; afterwards changes happen inside WordPress.

## Hardening notes

- **No baked credentials.** The admin password is generated at first run or supplied by you, never stored in an image layer.
- **Digest-pinned build.** The base image and WooCommerce version are fixed for a reproducible, auditable build.
- **Readiness gate.** The healthcheck stays unhealthy until the store is fully provisioned, so the platform never routes to a partial site.
- **Keep MariaDB and Redis private.** Do not publish their ports to the host or the internet.
- **After first login,** set up payments and shipping, keep WooCommerce and WordPress updated, and enable strong authentication for administrators.

## Backups

Capture the database and the content volume together:

1. **The MariaDB database:**
   ```
   docker compose exec db mariadb-dump -u root -p"$DB_ROOT_PASSWORD" woocommerce > woocommerce-db.sql
   ```
2. **The content volume** (uploads, installed plugins and themes):
   ```
   docker run --rm -v woocommerce_wp-content:/data -v "$PWD":/backup alpine \
     tar czf /backup/woocommerce-wp-content.tgz -C /data .
   ```

On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; WordPress and WooCommerce run any database migrations they need on start:
  ```
  docker compose pull woocommerce && docker compose up -d woocommerce
  ```
- **Core, WooCommerce, and our plugins come from the image; your uploads and installed extensions come from the volume,** so a retag upgrades the platform without wiping content.
- **Back up first,** and keep the database dump and the `wp-content` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image, WooCommerce version, and any behavior changes.

## FAQ

**Do I need a database?**
Yes. WooCommerce stores products, orders, and settings in MariaDB (or MySQL). The standalone compose file includes MariaDB and Redis.

**Is WooCommerce already installed?**
Yes. WooCommerce is baked into the image and activated on first run, so the store pages and tables exist as soon as the container is healthy. You still complete the store setup (payments, shipping, tax) in the WordPress admin.

**Where does the admin password come from?**
If you set `WP_ADMIN_PASSWORD`, that value is used. If you leave it empty, the image generates a strong one on first run and prints it once to the container log.

**How does HTTPS work if the container only serves HTTP on port 80?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which sets `X-Forwarded-Proto` and `X-Forwarded-Host`; the image derives the canonical HTTPS URL from those headers, which matters for checkout and payment redirects.

**Can I add other plugins and themes?**
Yes. Anything you install goes to the `wp-content` volume and persists across restarts and upgrades.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/woocommerce:11.1.0-r1`. Avoid moving tags so a redeploy cannot change the image under you.

---
title: "PrestaShop on Docker (Production): the RemarkableCloud image"
slug: prestashop
meta_description: "Run PrestaShop on Docker in production: digest-pinned, headless install, generated admin, MariaDB, proxy-aware, healthcheck, with compose and backups."
keywords:
  - prestashop docker
  - prestashop docker compose
  - self-hosted online store
  - prestashop behind traefik
  - prestashop mariadb
  - prestashop production
  - open source ecommerce docker
---

# PrestaShop on Docker, ready for production

PrestaShop is an open source ecommerce platform for building and running an online store: a product catalog, cart and checkout, orders, customers, shipping, taxes, and a large module and theme ecosystem. This page covers the RemarkableCloud PrestaShop image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by MariaDB.

## What the RemarkableCloud image adds

The image is a production-oriented build of the upstream `prestashop/prestashop` image that keeps the official runtime and adds turnkey, hardened provisioning:

- **Digest-pinned, stable version.** Built from `prestashop/prestashop@sha256:fb50922a7a8dafdd5b824b35ab7b58fd9c4fb7cd189a3699b9527e2dfb8e8033` (PrestaShop 8.2.8, PHP 8.1, Apache, Debian 12). We pin the stable 8.2 line: the current `latest` (9.1) has a broken headless installer upstream, so this image tracks the version that installs cleanly and by digest for reproducibility.
- **Headless install.** With the database and domain variables set, PrestaShop installs on first start with no web installer step, so the store is ready to use immediately.
- **No default credentials.** Upstream installs an `admin` / `prestashop_demo` account at `/admin`. Our image generates a strong admin password and a randomized admin-folder name on first run, keeps both in the data volume, and prints the login and admin URL path once to the container log. You can pin the password with `ADMIN_PASSWD`.
- **Proxy-aware.** Behind a TLS-terminating reverse proxy, `X-Forwarded-Proto: https` is mapped to HTTPS and SSL is enabled, so the storefront serves cleanly without the redirect loops PrestaShop is prone to behind a proxy.
- **Healthcheck.** A static `/rc-health.txt`, served directly by Apache and independent of PrestaShop routing or the shop domain, backs the container `HEALTHCHECK` so the platform routes traffic only once the store is serving.

The current published tag is `ghcr.io/remarkablecloud/prestashop:8.2.8-r1`.

PrestaShop is a trademark of its respective owner. RemarkableCloud packages the open source project and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **PrestaShop (Apache and PHP)** serves plain HTTP on port `80`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform). Set `PS_DOMAIN` to the public hostname so shop URLs match the request.
- **MariaDB** is a separate database container and holds products, orders, customers, and configuration.
- **A data volume** at `/var/www/html` holds the PrestaShop application, uploaded product images, and installed modules and themes.

## Docker Compose walkthrough

The standalone stack (PrestaShop and MariaDB) is defined in the image's `docker-compose.yml`:

```yaml
name: prestashop
services:
  db:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: prestashop
      MARIADB_USER: prestashop
      MARIADB_PASSWORD: ${DB_PASSWORD:-change-me-db}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-change-me-root}
    volumes: [db-data:/var/lib/mysql]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 12
  prestashop:
    image: ${PRESTASHOP_IMAGE:-ghcr.io/remarkablecloud/prestashop:8.2.8-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8094}:80"]
    environment:
      DB_SERVER: db
      DB_PORT: "3306"
      DB_NAME: prestashop
      DB_USER: prestashop
      DB_PASSWD: ${DB_PASSWORD:-change-me-db}
      PS_DOMAIN: ${PS_DOMAIN:-localhost:8094}
      ADMIN_MAIL: ${ADMIN_MAIL:-admin@example.com}
    volumes:
      - ps-data:/var/www/html
volumes:
  db-data:
  ps-data:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against MariaDB.
2. **Install is headless.** `DB_*` and `PS_DOMAIN` let PrestaShop install on first start without the web wizard.
3. **The admin password and folder are generated.** Leave `ADMIN_PASSWD` empty and the image creates a strong password and a randomized admin folder on first run and logs both once.
4. **Only the web port is exposed.** `${HTTP_PORT:-8094}:80` is for local use; in production the proxy connects to port `80` on the internal network.
5. **State lives in volumes.** `ps-data` (`/var/www/html`) and `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then browse to `http://localhost:8094` and read the admin login and admin URL path from `docker compose logs prestashop`. For production, set `PS_DOMAIN` to your public hostname and put the container behind a TLS-terminating reverse proxy.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed MariaDB; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `DB_SERVER` | yes | `<db_host>` | MariaDB host. |
| `DB_PORT` | no | `3306` | MariaDB port. |
| `DB_NAME` | yes | `<db_name>` | Database name. |
| `DB_USER` | yes | `<db_user>` | Database user. |
| `DB_PASSWD` | yes | `<db_password>` | Database password. |
| `PS_DOMAIN` | yes | `<hostname>` | Public shop domain, used for URL generation. |
| `ADMIN_MAIL` | no | `admin@example.com` | Admin email created at install. |
| `ADMIN_PASSWD` | no | (generated) | Admin password. Leave empty to auto-generate on first run (printed once); set it to pin your own. |

`PS_INSTALL_AUTO=1` and `PS_ENABLE_SSL=1` are baked into the image. Only the first run reads the install variables; afterwards changes happen inside PrestaShop.

## Hardening notes

- **No default credentials.** Both the admin password and the admin-folder name are generated on first run, never left at the upstream defaults.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/rc-health.txt` must return success before the platform routes requests.
- **Keep MariaDB private.** Do not publish its port to the host or the internet.
- **After first login,** note the admin URL path from the log, set up payments and shipping, keep PrestaShop and its modules updated, and remove the demo products if not needed.

## Backups

Capture the database and the data volume together:

1. **The MariaDB database:**
   ```
   docker compose exec db mariadb-dump -u root -p"$DB_ROOT_PASSWORD" prestashop > prestashop-db.sql
   ```
2. **The data volume** at `/var/www/html` (application, product images, modules, themes):
   ```
   docker run --rm -v prestashop_ps-data:/data -v "$PWD":/backup alpine \
     tar czf /backup/prestashop-data.tgz -C /data .
   ```

On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **PrestaShop upgrades in-app.** PrestaShop populates its whole application into the data volume on first run and manages core upgrades through its own 1-click upgrade module. Use that to move between PrestaShop versions.
- **Image `-r` tags bump the base.** A new image tag updates the base OS and PHP; it does not replace the PrestaShop application already in your volume. Back up first, then apply base updates by pulling the new tag and recreating the container.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. PrestaShop stores products, orders, and settings in MariaDB (or MySQL). The standalone compose file includes MariaDB.

**Where do the admin login and admin URL come from?**
On first run the image generates the admin password and a randomized admin-folder name and prints both once to the container log. Set `ADMIN_PASSWD` to pin the password.

**Why PrestaShop 8.2 and not 9.x?**
The current upstream `latest` (9.1) has a broken headless installer, so this image pins the stable 8.2 line that installs cleanly. A 9.x image will follow once the upstream installer is fixed.

**How does HTTPS work if the container only serves HTTP on port 80?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which sets `X-Forwarded-Proto: https`; the image maps that to HTTPS so PrestaShop generates https URLs and does not redirect-loop. Set `PS_DOMAIN` to the public hostname.

**Can I use MySQL instead of MariaDB?**
Yes. PrestaShop connects with the MySQL driver, which works with both MySQL 8 and MariaDB; point `DB_SERVER` at your server.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/prestashop:8.2.8-r1`. Avoid moving tags so a redeploy cannot change the image under you.

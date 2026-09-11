---
title: "Odoo on Docker (Production): the RemarkableCloud image"
slug: odoo
meta_description: "Run Odoo on Docker in production: open source ERP and CRM on PostgreSQL, digest-pinned, generated master password, with compose and backup notes."
keywords:
  - odoo docker
  - odoo docker compose
  - self-hosted erp
  - odoo postgresql
  - odoo behind traefik
  - odoo community production
  - open source crm erp
---

# Odoo on Docker, ready for production

Odoo is an open source suite of integrated business applications: ERP, CRM, accounting, inventory, sales, projects, a website builder, and dozens more, all sharing one database. This page covers the RemarkableCloud Odoo image: what it is, what our build adds on top of upstream, and how to run it in production with Docker Compose behind a reverse proxy, backed by PostgreSQL.

## What the RemarkableCloud image adds

The image is a production-oriented build of the official `odoo` image that keeps the official runtime and adds a security fix and turnkey provisioning:

- **Digest-pinned base.** Built from `odoo:18@sha256:c01e5bc381f087a3be2800d65cff8ad51ab0709dc54c3b81cd9b0d6c9b3a4d77` (Odoo 18.0 Community, Python 3.12). Pinning by digest keeps rebuilds reproducible.
- **No insecure master password.** Odoo's database manager is protected by a master password that upstream leaves at the default `admin`. Our image generates a strong one on first run, persists it in the filestore volume, and prints it once, so only you can create or drop databases.
- **PostgreSQL.** The connection is configured from `HOST` / `PORT` / `USER` / `PASSWORD`; Odoo waits for the database before starting.
- **Persistent filestore.** Attachments and sessions live in the `/var/lib/odoo` volume.
- **Healthcheck.** A container `HEALTHCHECK` polls `/web/health` so the platform routes traffic only once Odoo is serving.

The current published tag is `ghcr.io/remarkablecloud/odoo:18.0-r1`.

Odoo is a trademark of Odoo S.A. RemarkableCloud packages the open source Community edition and is not affiliated with or endorsed by the upstream project.

## Architecture at a glance

- **Odoo** serves on port `8069`. TLS is terminated upstream by a reverse proxy (Traefik on the RemarkableCloud App Platform).
- **PostgreSQL** is a separate database container; the user Odoo connects with must be able to create databases (the manager creates one per Odoo instance).
- **A data volume** at `/var/lib/odoo` holds the filestore (attachments, sessions) and the generated master password.

## Docker Compose walkthrough

The standalone stack (Odoo and PostgreSQL) is defined in the image's `docker-compose.yml`:

```yaml
name: odoo
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: ${DB_PASSWORD:-change-me-db}
      POSTGRES_DB: postgres
    volumes: [db-data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U odoo"]
      interval: 10s
      timeout: 5s
      retries: 12
  odoo:
    image: ${ODOO_IMAGE:-ghcr.io/remarkablecloud/odoo:18.0-r1}
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports: ["${HTTP_PORT:-8069}:8069"]
    environment:
      HOST: db
      PORT: "5432"
      USER: odoo
      PASSWORD: ${DB_PASSWORD:-change-me-db}
    volumes:
      - odoo-data:/var/lib/odoo
volumes:
  db-data:
  odoo-data:
```

Step by step:

1. **The app waits for the database.** `depends_on` with `condition: service_healthy` avoids a first-boot race against PostgreSQL.
2. **The database user can create databases.** The compose uses the Postgres superuser (`POSTGRES_USER`), so Odoo's manager can create the instance database.
3. **You create your database on first access.** Open Odoo, use the master password (from the log) in the database manager to create your database, choose the apps you want, and set your admin email and password.
4. **Only the web port is exposed.** `${HTTP_PORT:-8069}:8069` is for local use; in production the proxy connects to port `8069` on the internal network.
5. **State lives in volumes.** `odoo-data` (`/var/lib/odoo`) and `db-data` persist across restarts and upgrades.

To start it locally:

```
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
```

Then read the master password from `docker compose logs odoo`, open `http://localhost:8069`, and create your database.

## Environment variable reference

These are wired automatically by the App Platform backend from the managed PostgreSQL; they are listed here for standalone and self-hosted runs.

| Variable | Required | Value / default | Purpose |
|---|---|---|---|
| `HOST` | yes | `<db_host>` | PostgreSQL host. |
| `PORT` | no | `5432` | PostgreSQL port. |
| `USER` | yes | `<db_user>` | PostgreSQL user (must be able to create databases). |
| `PASSWORD` | yes | `<db_password>` | PostgreSQL password. |

The master password (`admin_passwd`) is generated on first run and stored in the data volume; it is not an environment variable.

## Hardening notes

- **Strong master password.** The database manager is never left at the insecure `admin` default; a generated master password is required to create or drop databases.
- **No baked credentials.** The master password is generated at runtime and stored only in the data volume.
- **Digest-pinned base.** Each build is auditable and reproducible.
- **Healthcheck gates traffic.** `/web/health` must return success before the platform routes requests.
- **Keep PostgreSQL private.** Do not publish its port to the host or the internet.
- **After creating your database,** you can further harden by disabling the database manager (`list_db = False`) once you no longer need to create databases.

## Backups

Capture the database and the data volume together:

1. **The PostgreSQL database** (use your Odoo database name):
   ```
   docker compose exec db pg_dump -U odoo <your-odoo-db> > odoo-db.sql
   ```
2. **The data volume** at `/var/lib/odoo` (filestore: attachments, sessions):
   ```
   docker run --rm -v odoo_odoo-data:/data -v "$PWD":/backup alpine \
     tar czf /backup/odoo-data.tgz -C /data .
   ```

Odoo also has a built-in backup in the database manager (database + filestore in one zip). On the RemarkableCloud App Platform, database and volume backups follow the platform's backup schedule.

## Upgrades

- **New builds ship as new `-r` tags.** Pull the new tag and recreate the container; Odoo applies module updates on start when needed:
  ```
  docker compose pull odoo && docker compose up -d odoo
  ```
- **Major Odoo version upgrades** (for example 18 to 19) are done with Odoo's upgrade process, not a simple image swap; read the upstream upgrade notes first.
- **Back up first,** and keep the database dump and the `/var/lib/odoo` archive from just before the upgrade.
- **Read the changelog.** Every build is listed in `CHANGELOG.md` with the base image digest and any behavior changes.

## FAQ

**Do I need a database?**
Yes. Odoo stores everything in PostgreSQL. The standalone compose file includes it, using the superuser so Odoo's manager can create the instance database.

**What is the master password?**
It protects Odoo's database manager (create, duplicate, drop, backup). The image generates a strong one on first run and prints it once to the container log; you use it to create your database.

**How do I set my admin login?**
When you create your database in the manager, you set the admin email and password there; that is your day-to-day login (separate from the master password).

**How does HTTPS work if the container serves HTTP on 8069?**
TLS is terminated at the reverse proxy (Traefik on the App Platform), which forwards to port `8069` on the internal network.

**Which tag should I run?**
Use the current pinned tag, `ghcr.io/remarkablecloud/odoo:18.0-r1`. Avoid moving tags so a redeploy cannot change the image under you.

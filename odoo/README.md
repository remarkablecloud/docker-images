# Odoo

Odoo, an open source suite of business apps (ERP, CRM, accounting, inventory, sales, website, and more), packaged by RemarkableCloud with a digest-pinned base, a PostgreSQL backend, and a strong master password generated on first run so the database manager is never left at the insecure default. You create your database, choosing the apps you need, via the manager on first access, gated by that master password; it runs behind a TLS-terminating reverse proxy.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/odoo:18.0-r1
```

## Quick start

A standalone stack (Odoo + PostgreSQL) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# browse http://localhost:8069 ; the master password is printed in `docker compose logs odoo`.
# Use it in the database manager to create your database and set your admin login.
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Odoo (Community): LGPL-3.0

# Plausible

Plausible Community Edition, a privacy-friendly, cookieless web analytics platform (a lightweight self-hosted alternative to Google Analytics), packaged by RemarkableCloud with a digest-pinned base, PostgreSQL and ClickHouse datastores, and a generated admin (owner) created on first boot so the first visitor can never claim the owner role. Both databases are created and migrated automatically on boot, self-registration is invite-only by default, and the app runs as a non-root user behind a TLS-terminating reverse proxy.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/plausible:3.2.1-r1
```

## Quick start

A standalone stack (Plausible + PostgreSQL + ClickHouse) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) CH_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# first boot creates both databases, migrates, and inserts the admin (about 40 to 90 seconds); the
# admin login is printed in `docker compose logs plausible`, then browse http://localhost:8095
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Plausible Community Edition: AGPL-3.0.

# Metabase

Metabase, open source business intelligence (dashboards, questions, and charts over your databases), packaged by RemarkableCloud from the OSS edition with a digest-pinned base, a persisted encryption key so the credentials of stored data sources are encrypted at rest, and an administrator created with a generated password on first boot so the first visitor can never claim the admin role. Metabase keeps its own state in an application database; point the container at PostgreSQL with `MB_DB_*` and it is otherwise stateless.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/metabase:0.63.17.2-r1
```

## Quick start

A standalone stack (Metabase + PostgreSQL app database) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# first boot migrates the app DB (about 1 to 3 min); the admin login is printed in
# `docker compose logs metabase`, then browse http://localhost:8096
```

## More

Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Metabase: AGPL-3.0 (the open source edition; the separately licensed Enterprise edition is not used in this image).

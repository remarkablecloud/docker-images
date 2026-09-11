# Chatwoot

Chatwoot, an open source customer engagement platform (live chat and a shared inbox, a self-hosted alternative to Zendesk and Intercom), packaged by RemarkableCloud with a digest-pinned base, a PostgreSQL (pgvector) and Redis backend, and a super administrator created with a generated password on first run so the first visitor can never claim the admin role. The web and worker processes run together in one container behind a TLS-terminating reverse proxy, with self-registration disabled by default.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/chatwoot:4.17.1-r1
```

## Quick start

A standalone stack (Chatwoot + PostgreSQL/pgvector + Redis) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) REDIS_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# first boot loads the schema and migrates (~2-3 min); the admin login is printed in
# `docker compose logs chatwoot`, then browse http://localhost:3099
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Chatwoot: MIT (with a separately licensed `enterprise/` directory, not enabled in this image).

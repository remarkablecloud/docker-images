# Mattermost

Mattermost, an open source team messaging platform and self-hosted alternative to Slack, packaged by RemarkableCloud with a digest-pinned base, a PostgreSQL backend, and a system administrator created with a generated password on first run so the first visitor can never claim the admin role. It runs behind a TLS-terminating reverse proxy with open sign-up disabled by default.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/mattermost:11.10.1-r1
```

## Quick start

A standalone stack (Mattermost + PostgreSQL) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:8099 ; the admin login is printed in `docker compose logs mattermost`
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Mattermost (Team Edition): AGPL-3.0

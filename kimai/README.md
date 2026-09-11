# Kimai

Kimai, an open source time-tracking application, packaged by RemarkableCloud with a digest-pinned base, an env-driven install, and an admin account created with a generated password on first run. It runs behind a TLS-terminating reverse proxy with a MariaDB database; the application stays in the image while your data and app secret persist in a volume, so an image update refreshes the code without touching your content.

## Pull

```bash
docker pull ghcr.io/remarkablecloud/kimai:2.66.0-r1
```

## Quick start

A standalone stack (Kimai + MariaDB) is defined in [`docker-compose.yml`](./docker-compose.yml):

```bash
DB_PASSWORD=$(openssl rand -hex 16) docker compose up -d
# then browse http://localhost:8098 ; the admin login is printed in `docker compose logs kimai`
```

## More

Full documentation (compose walkthrough, environment reference, hardening, backup, and upgrade guidance) is authored in [`site.md`](./site.md). Build history and security-relevant changes are in [`CHANGELOG.md`](./CHANGELOG.md).

**Upstream license:** Kimai: AGPL-3.0
